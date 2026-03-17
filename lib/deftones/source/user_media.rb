# frozen_string_literal: true

module Deftones
  module Source
    class UserMedia < Core::Source
      DeviceInfo = Struct.new(:device_id, :label, :group_id, :input_channels, :output_channels, keyword_init: true)

      attr_reader :buffer, :provider, :device_id, :group_id, :label

      def initialize(buffer: nil, provider: nil, loop: false, live: false, capture_backend: nil,
                     device_id: nil, group_id: nil, label: nil, channels: nil, context: Deftones.context)
        super(context: context)
        @buffer = normalize_buffer(buffer)
        @provider = normalize_provider(provider)
        @loop = loop
        @live_requested = live || !capture_backend.nil?
        @capture_backend = normalize_capture_backend(capture_backend, live, channels)
        @device_id = device_id
        @group_id = group_id
        @label = label
        @channels = normalize_channel_count(channels)
        @sample_cursor = 0
        @opened = false
      end

      def start(time = nil)
        rewind
        @capture_backend&.start
        @opened = true
        super
      end

      def stop(time = nil)
        @capture_backend&.stop
        super
      end

      def open(time = nil, device_id: nil, group_id: nil, label: nil)
        @device_id = device_id unless device_id.nil?
        @group_id = group_id unless group_id.nil?
        @label = label unless label.nil?
        open_capture_backend!
        sync_capture_metadata!
        self.class.grant_permissions!
        start(time)
      end

      def close(time = nil)
        stop(time)
        @capture_backend&.close if @capture_backend.respond_to?(:close)
        @opened = false
        self
      end

      def rewind
        @sample_cursor = 0
        @provider.rewind if @provider.respond_to?(:rewind)
        @capture_backend&.rewind if @capture_backend.respond_to?(:rewind)
        self
      end

      def live?
        @live_requested
      end

      def opened?
        @opened
      end

      def permission_state
        self.class.permission_state
      end

      alias permissionState permission_state

      def state(time = context.current_time)
        return :stopped unless @opened

        active_at?(resolve_time(time)) ? :started : :stopped
      end

      def dispose
        close
        super
      end

      class << self
        def permission_state
          @permission_state ||= :prompt
        end

        def grant_permissions!
          @permission_state = :granted
          self
        end

        def reset_permissions!
          @permission_state = :prompt
          self
        end

        def supported?
          true
        end

        def input_devices
          portaudio_devices.filter_map do |device|
            info = build_device_info(device)
            info if info.input_channels.positive?
          end
        end

        def enumerate_devices
          input_devices
        end

        alias supported supported?
        alias enumerateDevices enumerate_devices
        alias permissionState permission_state

        private

        def permissions_granted?
          permission_state == :granted
        end

        def portaudio_devices
          return [] unless Deftones.portaudio_available?
          return [] unless defined?(PortAudio::Device)

          return Array(PortAudio::Device.all) if PortAudio::Device.respond_to?(:all)
          return Array(PortAudio::Device.devices) if PortAudio::Device.respond_to?(:devices)

          []
        rescue StandardError
          []
        end

        def build_device_info(device)
          DeviceInfo.new(
            device_id: extract_device_id(device),
            label: exposed_device_label(device),
            group_id: exposed_device_group_id(device),
            input_channels: extract_device_channels(device, :input),
            output_channels: extract_device_channels(device, :output)
          )
        end

        def extract_device_id(device)
          return device.device_id if device.respond_to?(:device_id)
          return device.index if device.respond_to?(:index)
          return device.device_index if device.respond_to?(:device_index)

          extract_device_label(device)
        end

        def extract_device_label(device)
          return device.label if device.respond_to?(:label)
          return device.name if device.respond_to?(:name)

          device.to_s
        end

        def extract_device_group_id(device)
          return device.group_id if device.respond_to?(:group_id)
          return device.host_api if device.respond_to?(:host_api)
          return device.host_api_name if device.respond_to?(:host_api_name)

          nil
        end

        def exposed_device_label(device)
          permissions_granted? ? extract_device_label(device) : ""
        end

        def exposed_device_group_id(device)
          permissions_granted? ? extract_device_group_id(device) : nil
        end

        def extract_device_channels(device, direction)
          methods =
            case direction
            when :input then %i[max_input_channels input_channels channels]
            when :output then %i[max_output_channels output_channels channels]
            else []
            end

          methods.each do |method_name|
            return device.public_send(method_name).to_i if device.respond_to?(method_name)
          end

          0
        end
      end

      def process(_input_buffer, num_frames, start_frame, _cache)
        return render_buffer_block(num_frames, start_frame) if @buffer && @buffer.channels > 1
        return render_capture_block(num_frames, start_frame) if @capture_backend && capture_channels > 1
        return render_buffer(num_frames, start_frame) if @buffer
        return render_capture(num_frames, start_frame) if @capture_backend

        Array.new(num_frames) do |index|
          current_time = (start_frame + index).to_f / context.sample_rate
          next 0.0 unless active_at?(current_time)

          next_provider_sample
        end
      end

      private

      def multichannel_process?
        (@buffer && @buffer.channels > 1) || capture_channels > 1
      end

      def capture_channels
        return @buffer.channels if @buffer
        return normalize_channel_count(@capture_backend.channels) if @capture_backend.respond_to?(:channels)

        @channels
      end

      def normalize_buffer(buffer)
        return if buffer.nil?

        buffer.is_a?(IO::Buffer) ? buffer : IO::Buffer.load(buffer)
      end

      def normalize_provider(provider)
        return if provider.nil?
        return provider if provider.respond_to?(:call)

        provider.to_enum
      end

      def normalize_capture_backend(capture_backend, live, channels)
        return capture_backend if capture_backend
        return unless live && Deftones.portaudio_available?

        PortAudioCapture.new(
          sample_rate: context.sample_rate,
          buffer_size: context.buffer_size,
          channels: normalize_channel_count(channels || context.channels)
        )
      end

      def normalize_channel_count(channels)
        [channels.to_i, 1].max
      end

      def open_capture_backend!
        return self unless live?

        raise Deftones::MissingRealtimeBackendError, "UserMedia live capture backend is unavailable" unless @capture_backend

        if @capture_backend.respond_to?(:open)
          @capture_backend.open(
            device_id: @device_id,
            group_id: @group_id,
            label: @label,
            channels: capture_channels
          )
        end

        self
      end

      def sync_capture_metadata!
        return self unless @capture_backend

        @device_id = @capture_backend.device_id if @capture_backend.respond_to?(:device_id) && !@capture_backend.device_id.nil?
        @group_id = @capture_backend.group_id if @capture_backend.respond_to?(:group_id) && !@capture_backend.group_id.nil?
        @label = @capture_backend.label if @capture_backend.respond_to?(:label) && !@capture_backend.label.nil?
        self
      end

      def render_buffer(num_frames, start_frame)
        Array.new(num_frames) do |index|
          current_time = (start_frame + index).to_f / context.sample_rate
          next 0.0 unless active_at?(current_time)

          sample_position = (current_time - @start_time) * @buffer.sample_rate
          if @loop && @buffer.frames.positive?
            sample_position %= @buffer.frames
          elsif sample_position >= @buffer.frames
            @opened = false
            next 0.0
          end

          @buffer.sample_at(sample_position)
        end
      end

      def render_buffer_block(num_frames, start_frame)
        output = Array.new(@buffer.channels) { Array.new(num_frames, 0.0) }

        num_frames.times do |index|
          current_time = (start_frame + index).to_f / context.sample_rate
          next unless active_at?(current_time)

          sample_position = (current_time - @start_time) * @buffer.sample_rate
          if @loop && @buffer.frames.positive?
            sample_position %= @buffer.frames
          elsif sample_position >= @buffer.frames
            @opened = false
            next
          end

          @buffer.channels.times do |channel_index|
            output[channel_index][index] = @buffer.sample_at(sample_position, channel_index)
          end
        end

        Core::AudioBlock.from_channel_data(output)
      end

      def render_capture(num_frames, start_frame)
        Array.new(num_frames) do |index|
          current_time = (start_frame + index).to_f / context.sample_rate
          next 0.0 unless active_at?(current_time)

          @capture_backend.next_sample
        end
      end

      def render_capture_block(num_frames, start_frame)
        output = Array.new(capture_channels) { Array.new(num_frames, 0.0) }

        num_frames.times do |index|
          current_time = (start_frame + index).to_f / context.sample_rate
          next unless active_at?(current_time)

          frame = next_capture_frame
          capture_channels.times do |channel_index|
            output[channel_index][index] = frame[channel_index] || 0.0
          end
        end

        Core::AudioBlock.from_channel_data(output)
      end

      def next_capture_frame
        return Array.new(capture_channels, 0.0) unless @capture_backend

        frame = if @capture_backend.respond_to?(:next_frame)
          @capture_backend.next_frame
        else
          @capture_backend.next_sample
        end

        frame = [frame] unless frame.is_a?(Array)
        normalized = frame.map(&:to_f)
        normalized.fill(0.0, normalized.length...capture_channels)
      end

      def next_provider_sample
        return 0.0 unless @provider

        sample = if @provider.respond_to?(:call)
          @provider.call(@sample_cursor)
        else
          next_enumerator_sample
        end
        @sample_cursor += 1
        sample.to_f
      end

      def next_enumerator_sample
        @provider.next
      rescue StopIteration
        return 0.0 unless @loop && @provider.respond_to?(:rewind)

        @provider.rewind
        @provider.next
      rescue StopIteration
        @opened = false
        0.0
      end

      class PortAudioCapture
        attr_reader :channels, :device_id, :group_id, :label

        def initialize(sample_rate:, buffer_size:, channels: 1)
          @sample_rate = sample_rate
          @buffer_size = buffer_size
          @channels = [channels.to_i, 1].max
          @queue = Queue.new
          @max_frames = buffer_size * 64
          @stream = nil
          @device_id = nil
          @group_id = nil
          @label = nil
        end

        def open(device_id: nil, group_id: nil, label: nil, channels: nil)
          @device_id = device_id unless device_id.nil?
          @group_id = group_id unless group_id.nil?
          @label = label unless label.nil?
          @channels = [channels.to_i, 1].max unless channels.nil?
          close if @stream
          self
        end

        def start
          open_stream unless @stream
          @stream.start
          self
        end

        def stop
          return self unless @stream
          return self if @stream.stopped?

          @stream.stop
          self
        end

        def rewind
          clear_queue
          self
        end

        def close
          return self unless @stream

          stream = @stream
          @stream = nil
          clear_queue
          stream.close
          self
        ensure
          Deftones::PortAudioSupport.release
        end

        def next_sample
          frame = next_frame
          frame.sum / [frame.length, 1].max.to_f
        rescue ThreadError
          0.0
        end

        def next_frame
          @queue.pop(true)
        rescue ThreadError
          Array.new(@channels, 0.0)
        end

        private

        def open_stream
          Deftones::PortAudioSupport.acquire!
          input_parameters = Deftones::PortAudioSupport.input_parameters(
            @channels,
            device_id: @device_id,
            label: @label
          )
          assign_device_metadata(input_parameters[:device])
          @stream = PortAudio::Stream.new(
            input: input_parameters,
            sample_rate: @sample_rate.to_f,
            frames_per_buffer: @buffer_size,
            &method(:process)
          )
        rescue StandardError
          Deftones::PortAudioSupport.release
          raise
        end

        def process(input, _output, frame_count, _time_info, _status_flags, _user_data)
          return :continue if input.null?

          input.read_array_of_float(frame_count * @channels).each_slice(@channels) do |frame|
            @queue << frame.map(&:to_f)
          end
          trim_queue!
          :continue
        rescue StandardError
          :abort
        end

        def assign_device_metadata(device)
          return unless device

          @device_id ||= if device.respond_to?(:device_id)
            device.device_id
          elsif device.respond_to?(:index)
            device.index
          elsif device.respond_to?(:device_index)
            device.device_index
          end
          @label ||= if device.respond_to?(:label)
            device.label
          elsif device.respond_to?(:name)
            device.name
          end
          @group_id ||= if device.respond_to?(:group_id)
            device.group_id
          elsif device.respond_to?(:host_api)
            device.host_api
          elsif device.respond_to?(:host_api_name)
            device.host_api_name
          end
        end

        def trim_queue!
          @queue.pop(true) while @queue.size > @max_frames
        rescue ThreadError
          nil
        end

        def clear_queue
          @queue.pop(true) while true
        rescue ThreadError
          nil
        end
      end
    end
  end
end
