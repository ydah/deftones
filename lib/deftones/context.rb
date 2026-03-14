# frozen_string_literal: true

module Deftones
  class Context
    DEFAULT_SAMPLE_RATE = 44_100
    DEFAULT_BUFFER_SIZE = 256

    attr_reader :sample_rate, :buffer_size, :output

    def initialize(sample_rate: DEFAULT_SAMPLE_RATE, buffer_size: DEFAULT_BUFFER_SIZE)
      @sample_rate = sample_rate
      @buffer_size = buffer_size
      @output = Core::Gain.new(context: self, gain: 1.0)
      @running = false
      @started_at = monotonic_time
    end

    def start
      @started_at = monotonic_time
      @running = true
      self
    end

    def stop
      @running = false
      self
    end

    def running?
      @running
    end

    def current_time
      return 0.0 unless @running

      monotonic_time - @started_at
    end

    def render_frames(num_frames, start_frame = 0)
      @output.render(num_frames, start_frame, {})
    end

    private

    def monotonic_time
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
