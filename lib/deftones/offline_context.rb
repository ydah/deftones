# frozen_string_literal: true

module Deftones
  class OfflineContext < Context
    attr_reader :channels, :duration, :total_frames

    def initialize(duration:, channels: 2, sample_rate: DEFAULT_SAMPLE_RATE,
                   buffer_size: DEFAULT_BUFFER_SIZE)
      super(sample_rate: sample_rate, buffer_size: buffer_size, channels: channels, autostart: false)
      @duration = duration.to_f
      @total_frames = (@duration * sample_rate).ceil
    end

    def current_time
      0.0
    end

    def render
      Deftones.transport.prepare_render(@duration)
      samples = Array.new(@total_frames * @channels, 0.0)
      frames_processed = 0

      while frames_processed < @total_frames
        chunk_frames = [buffer_size, @total_frames - frames_processed].min
        mono_chunk = render_frames(chunk_frames, frames_processed)
        interleaved = IO::Buffer.interleave(mono_chunk, @channels)
        start_index = frames_processed * @channels

        samples[start_index, interleaved.length] = interleaved
        frames_processed += chunk_frames
      end

      IO::Buffer.new(samples, channels: @channels, sample_rate: sample_rate)
    end

    def render_to_file(path, format: :wav)
      rendered_buffer = render
      rendered_buffer.save(path, format: format)
      rendered_buffer
    end
  end
end
