# frozen_string_literal: true

module Deftones
  class Context
    DEFAULT_SAMPLE_RATE = 44_100
    DEFAULT_BUFFER_SIZE = 256
    DEFAULT_CHANNELS = 2

    attr_reader :sample_rate, :buffer_size, :channels, :stream_error

    def initialize(sample_rate: DEFAULT_SAMPLE_RATE, buffer_size: DEFAULT_BUFFER_SIZE, channels: DEFAULT_CHANNELS,
                   realtime_backend: nil, autostart: true)
      @sample_rate = sample_rate
      @buffer_size = buffer_size
      @channels = channels
      @realtime_backend = realtime_backend
      @autostart = autostart
      @output = Core::Gain.new(context: self, gain: 1.0)
      @running = false
      @started_at = monotonic_time
      @stream = nil
      @rendered_frames = 0
      @stream_error = nil
    end

    def start(use_realtime: true)
      @started_at = monotonic_time
      @rendered_frames = 0
      @stream_error = nil
      @running = true
      start_realtime_stream if use_realtime
      self
    end

    def stop
      @stream&.stop
      @stream&.close if @stream.respond_to?(:close)
      @stream = nil
      @running = false
      self
    end

    def running?
      @running
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
      @output.render(num_frames, start_frame, {})
    end

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
      chunk = render_frames(frames, @rendered_frames)
      @rendered_frames += frames
      IO::Buffer.interleave(chunk, @channels)
    end

    def monotonic_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    class PortAudioOutputStream
      def initialize(context:)
        @context = context
        @callback = method(:process)
        @stream_buffer = nil
        @open = false
      end

      def start
        open_stream unless @open
        Deftones::PortAudioSupport.check_error!(api.Pa_StartStream(stream_pointer))
        self
      end

      def stop
        return self unless @open

        result = api.Pa_StopStream(stream_pointer)
        return self if result == :paNoError || result == :paStreamIsStopped || result == 0

        Deftones::PortAudioSupport.check_error!(result)
        self
      end

      def close
        return self unless @open

        result = api.Pa_CloseStream(stream_pointer)
        @stream_buffer = nil
        @open = false
        Deftones::PortAudioSupport.check_error!(result)
        self
      ensure
        Deftones::PortAudioSupport.release
      end

      def time
        return 0.0 unless @open

        api.Pa_GetStreamTime(stream_pointer)
      end

      private

      def open_stream
        Deftones::PortAudioSupport.acquire!
        output = Deftones::PortAudioSupport.output_parameters(@context.channels)
        @stream_buffer = FFI::Buffer.new(:pointer)
        result = api.Pa_OpenStream(
          @stream_buffer,
          nil,
          output,
          @context.sample_rate.to_f,
          @context.buffer_size,
          api::NoFlag,
          @callback,
          nil
        )
        Deftones::PortAudioSupport.check_error!(result)
        @open = true
      rescue StandardError
        Deftones::PortAudioSupport.release
        raise
      end

      def process(_input, output, frame_count, _time_info, _status_flags, _user_data)
        output.write_array_of_float(@context.send(:pull_realtime_samples, frame_count))
        :paContinue
      rescue StandardError
        output.write_array_of_float(Array.new(frame_count * @context.channels, 0.0))
        :paAbort
      end

      def stream_pointer
        @stream_buffer.read_pointer
      end

      def api
        FFI::PortAudio::API
      end
    end
  end
end
