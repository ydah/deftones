# frozen_string_literal: true

module Deftones
  class Context
    DEFAULT_SAMPLE_RATE = 44_100
    DEFAULT_BUFFER_SIZE = 256
    DEFAULT_CHANNELS = 2

    attr_reader :buffer_size, :channels, :draw, :latency_hint, :look_ahead, :output_device_id,
                :output_device_label, :sample_rate, :stream_error, :stream_status_flags, :transport
    attr_accessor :on_stream_error

    def initialize(sample_rate: DEFAULT_SAMPLE_RATE, buffer_size: DEFAULT_BUFFER_SIZE, channels: DEFAULT_CHANNELS,
                   realtime_backend: nil, autostart: true, latency_hint: "interactive", look_ahead: nil,
                   transport: nil, draw: nil, on_stream_error: nil, stream_error_mode: :abort,
                   output_device_id: nil, output_device_label: nil)
      @sample_rate = sample_rate
      @buffer_size = buffer_size
      @channels = channels
      @transport = transport || Event::Transport.new(clock: self)
      @draw = draw || Draw.new
      @realtime_backend = realtime_backend
      @autostart = autostart
      @latency_hint = latency_hint
      @look_ahead = look_ahead || (buffer_size.to_f / sample_rate)
      @output_device_id = output_device_id
      @output_device_label = output_device_label
      @on_stream_error = on_stream_error
      @stream_error_mode = normalize_stream_error_mode(stream_error_mode)
      @output = Core::Gain.new(context: self, gain: 1.0)
      @running = false
      @closed = false
      @started_at = monotonic_time
      @stream = nil
      @rendered_frames = 0
      @stream_error = nil
      @stream_status_flags = []
    end

    def start(use_realtime: true)
      @closed = false
      @started_at = monotonic_time
      @rendered_frames = 0
      @stream_error = nil
      @stream_status_flags.clear
      @running = true
      start_realtime_stream if use_realtime
      self
    end

    def resume(use_realtime: true)
      start(use_realtime: use_realtime)
    end

    def stop
      @stream&.stop
      @stream&.close if @stream.respond_to?(:close)
      @stream = nil
      @running = false
      self
    end

    def close
      stop
      @closed = true
      self
    end

    def running?
      @running
    end

    def state
      return "closed" if @closed
      return "running" if running?

      "suspended"
    end

    def realtime?
      !@stream.nil?
    end

    def output
      start if @autostart && !running?
      @output
    end

    def current_time
      return @stream.time if @stream&.respond_to?(:time)
      return 0.0 unless @running

      monotonic_time - @started_at
    end

    def render_frames(num_frames, start_frame = 0)
      render_block_frames(num_frames, start_frame).mono
    end

    def render_block_frames(num_frames, start_frame = 0)
      @output.send(:render_block, num_frames, start_frame, {})
    end

    def raw_context
      self
    end

    def sample_time
      1.0 / sample_rate
    end

    def block_time
      buffer_size.to_f / sample_rate
    end

    def reset!
      stop
      @transport = Event::Transport.new(clock: self)
      @draw = Draw.new
      @stream_error = nil
      @stream_status_flags.clear
      @rendered_frames = 0
      self
    end

    alias rawContext raw_context
    alias sampleTime sample_time
    alias blockTime block_time
    alias latencyHint latency_hint
    alias lookAhead look_ahead
    alias outputDeviceId output_device_id
    alias outputDeviceLabel output_device_label
    alias onStreamError on_stream_error
    alias onStreamError= on_stream_error=

    def stream_error_mode
      @stream_error_mode
    end

    def stream_error_mode=(value)
      @stream_error_mode = normalize_stream_error_mode(value)
    end

    alias streamErrorMode stream_error_mode
    alias streamErrorMode= stream_error_mode=
    alias streamStatusFlags stream_status_flags

    private

    def start_realtime_stream
      return if @stream

      backend = build_realtime_backend
      return unless backend

      backend.start
      @stream = backend
    rescue StandardError => error
      backend&.close if backend.respond_to?(:close)
      @stream_error = error
      @stream = nil
    end

    def build_realtime_backend
      case @realtime_backend
      when nil
        return unless Deftones.portaudio_available?

        PortAudioOutputStream.new(context: self)
      when Class
        @realtime_backend.new(context: self)
      else
        @realtime_backend
      end
    end

    def pull_realtime_samples(frames)
      start_frame = @rendered_frames
      next_frame = start_frame + frames
      @transport.prepare_render_window(start_frame.to_f / sample_rate, next_frame.to_f / sample_rate)
      Deftones.transport.prepare_render_window(start_frame.to_f / sample_rate, next_frame.to_f / sample_rate) unless Deftones.transport.equal?(@transport)
      chunk = render_block_frames(frames, start_frame).fit_channels(@channels)
      @rendered_frames = next_frame
      @draw.advance_to(@rendered_frames.to_f / sample_rate)
      Deftones.draw.advance_to(@rendered_frames.to_f / sample_rate) unless Deftones.draw.equal?(@draw)
      chunk.interleaved
    end

    def handle_stream_error(error)
      @stream_error ||= error
      @on_stream_error&.call(error)
      @stream_error_mode == :continue ? :continue : :abort
    end

    def record_stream_status_flags(status_flags)
      return self if status_flags.nil?
      return self if status_flags.respond_to?(:zero?) && status_flags.zero?

      @stream_status_flags << status_flags
      self
    end

    def normalize_stream_error_mode(value)
      normalized = value.to_sym
      return normalized if %i[abort continue].include?(normalized)

      raise ArgumentError, "Unsupported stream error mode: #{value}"
    end

    def monotonic_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    class PortAudioOutputStream
      def initialize(context:)
        @context = context
        @stream = nil
        @silence_cache = {}
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

      def close
        return self unless @stream

        stream = @stream
        @stream = nil
        stream.close
        self
      ensure
        Deftones::PortAudioSupport.release
      end

      def time
        return 0.0 unless @stream

        @stream.time
      end

      private

      def open_stream
        Deftones::PortAudioSupport.acquire!
        @stream = PortAudio::Stream.new(
          output: Deftones::PortAudioSupport.output_parameters(
            @context.channels,
            device_id: @context.output_device_id,
            label: @context.output_device_label,
            sample_rate: @context.sample_rate
          ),
          sample_rate: @context.sample_rate.to_f,
          frames_per_buffer: @context.buffer_size,
          &method(:process)
        )
      rescue StandardError
        Deftones::PortAudioSupport.release
        raise
      end

      def process(_input, output, frame_count, _time_info, status_flags, _user_data)
        @context.send(:record_stream_status_flags, status_flags)
        output.write_array_of_float(@context.send(:pull_realtime_samples, frame_count))
        :continue
      rescue StandardError => error
        output.write_array_of_float(silence_for(frame_count)) unless output.null?
        @context.send(:handle_stream_error, error)
      end

      def silence_for(frame_count)
        @silence_cache[frame_count] ||= Array.new(frame_count * @context.channels, 0.0).freeze
      end
    end
  end
end
