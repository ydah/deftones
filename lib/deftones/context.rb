# frozen_string_literal: true

module Deftones
  class Context
    DEFAULT_SAMPLE_RATE = 44_100
    DEFAULT_BUFFER_SIZE = 256
    DEFAULT_CHANNELS = 2

    attr_reader :sample_rate, :buffer_size, :channels, :output

    def initialize(sample_rate: DEFAULT_SAMPLE_RATE, buffer_size: DEFAULT_BUFFER_SIZE, channels: DEFAULT_CHANNELS)
      @sample_rate = sample_rate
      @buffer_size = buffer_size
      @channels = channels
      @output = Core::Gain.new(context: self, gain: 1.0)
      @running = false
      @started_at = monotonic_time
      @stream = nil
      @rendered_frames = 0
    end

    def start(use_realtime: true)
      @started_at = monotonic_time
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
      return unless Deftones.portaudio_available?
      return if @stream

      @stream = FFI::PortAudio::Stream.new(
        sample_rate: @sample_rate,
        frames_per_buffer: @buffer_size,
        output_channels: @channels
      )
      @stream.start do |output_buffer, frames|
        write_realtime_chunk(output_buffer, frames)
      end
    rescue StandardError
      @stream = nil
    end

    def write_realtime_chunk(output_buffer, frames)
      chunk = render_frames(frames, @rendered_frames)
      @rendered_frames += frames
      samples = IO::Buffer.interleave(chunk, @channels)
      output_buffer.write_array_of_float(samples)
    end

    def monotonic_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
