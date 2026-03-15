# frozen_string_literal: true

module Deftones
  module Source
    class UserMedia < Core::Source
      attr_reader :buffer, :provider, :device_id, :group_id, :label

      def initialize(buffer: nil, provider: nil, loop: false, live: false, capture_backend: nil,
                     device_id: nil, group_id: nil, label: nil, context: Deftones.context)
        super(context: context)
        @buffer = normalize_buffer(buffer)
        @provider = normalize_provider(provider)
        @loop = loop
        @capture_backend = normalize_capture_backend(capture_backend, live)
        @device_id = device_id
        @group_id = group_id
        @label = label
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
        !@capture_backend.nil?
      end

      def opened?
        @opened
      end

      def state(time = context.current_time)
        return :stopped unless @opened

        active_at?(resolve_time(time)) ? :started : :stopped
      end

      def dispose
        close
        super
      end

      class << self
        def supported?
          true
        end

        alias supported supported?
      end

      def process(_input_buffer, num_frames, start_frame, _cache)
        return render_buffer(num_frames, start_frame) if @buffer
        return render_capture(num_frames, start_frame) if @capture_backend

        Array.new(num_frames) do |index|
          current_time = (start_frame + index).to_f / context.sample_rate
          next 0.0 unless active_at?(current_time)

          next_provider_sample
        end
      end

      private

      def normalize_buffer(buffer)
        return if buffer.nil?

        buffer.is_a?(IO::Buffer) ? buffer : IO::Buffer.load(buffer)
      end

      def normalize_provider(provider)
        return if provider.nil?
        return provider if provider.respond_to?(:call)

        provider.to_enum
      end

      def normalize_capture_backend(capture_backend, live)
        return capture_backend if capture_backend
        return unless live && Deftones.portaudio_available?

        PortAudioCapture.new(sample_rate: context.sample_rate, buffer_size: context.buffer_size)
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

      def render_capture(num_frames, start_frame)
        Array.new(num_frames) do |index|
          current_time = (start_frame + index).to_f / context.sample_rate
          next 0.0 unless active_at?(current_time)

          @capture_backend.next_sample
        end
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
        def initialize(sample_rate:, buffer_size:, channels: 1)
          @sample_rate = sample_rate
          @buffer_size = buffer_size
          @channels = channels
          @queue = Queue.new
          @max_samples = buffer_size * 64
          @stream = nil
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
          @queue.pop(true)
        rescue ThreadError
          0.0
        end

        private

        def open_stream
          Deftones::PortAudioSupport.acquire!
          @stream = PortAudio::Stream.new(
            input: Deftones::PortAudioSupport.input_parameters(@channels),
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
            @queue << (frame.sum / frame.length.to_f)
          end
          trim_queue!
          :continue
        rescue StandardError
          :abort
        end

        def trim_queue!
          @queue.pop(true) while @queue.size > @max_samples
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
