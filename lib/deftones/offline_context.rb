# frozen_string_literal: true

module Deftones
  class OfflineContext < Context
    attr_reader :channels, :duration, :total_frames, :current_frame

    def initialize(duration:, channels: 2, sample_rate: DEFAULT_SAMPLE_RATE,
                   buffer_size: DEFAULT_BUFFER_SIZE)
      super(sample_rate: sample_rate, buffer_size: buffer_size, channels: channels, autostart: false)
      @duration = duration.to_f
      @total_frames = (@duration * sample_rate).ceil
      @current_frame = 0
      @rendering = false
    end

    def current_time
      @current_frame.to_f / sample_rate
    end

    def state
      "suspended"
    end

    def render
      samples = Array.new(@total_frames * @channels, 0.0)

      render_each_block do |block, start_frame|
        interleaved = block.fit_channels(@channels).interleaved
        start_index = start_frame * @channels

        samples[start_index, interleaved.length] = interleaved
      end

      IO::Buffer.new(samples, channels: @channels, sample_rate: sample_rate)
    end

    def render_each_block
      return enum_for(:render_each_block) unless block_given?

      with_render_state do
        frames_processed = 0

        while frames_processed < @total_frames
          chunk_frames = [buffer_size, @total_frames - frames_processed].min
          @current_frame = frames_processed
          advance_schedulers(frames_processed, chunk_frames)
          yield render_block_frames(chunk_frames, frames_processed).fit_channels(@channels), frames_processed
          frames_processed += chunk_frames
        end

        @current_frame = @total_frames
      end

      self
    end

    alias renderEachBlock render_each_block

    def render_to_file(path, format: nil, streaming: false)
      return stream_to_file(path, format: format) if streaming

      rendered_buffer = render
      rendered_buffer.save(path, format: format)
      rendered_buffer
    end

    private

    def with_render_state
      previous_frame = @current_frame
      previous_rendering = @rendering
      @rendering = true
      @current_frame = 0
      yield
    ensure
      @current_frame = previous_frame
      @rendering = previous_rendering
    end

    def advance_schedulers(start_frame, chunk_frames)
      window_start = start_frame.to_f / sample_rate
      window_end = (start_frame + chunk_frames).to_f / sample_rate
      Deftones.transport.prepare_render_window(window_start, window_end)
      Deftones.draw.advance_to(window_end)
    end

    def stream_to_file(path, format: nil)
      resolved_format = format || File.extname(path).delete_prefix(".").downcase.to_sym
      resolved_format = :wav if resolved_format.nil? || resolved_format == :""
      raise UnsupportedAudioFormatError, "Streaming render only supports WAV output" unless resolved_format.to_sym == :wav

      File.open(path, "wb") do |file|
        file.write(wav_header)
        render_each_block do |block, _start_frame|
          file.write(pcm16_payload(block.fit_channels(@channels).interleaved))
        end
      end

      path
    end

    def wav_header
      bytes_per_sample = 2
      data_size = @total_frames * @channels * bytes_per_sample
      byte_rate = sample_rate * @channels * bytes_per_sample
      block_align = @channels * bytes_per_sample

      "RIFF" \
        + [36 + data_size].pack("V") \
        + "WAVEfmt " \
        + [16, 1, @channels, sample_rate, byte_rate, block_align, 16].pack("VvvVVvv") \
        + "data" \
        + [data_size].pack("V")
    end

    def pcm16_payload(samples)
      samples.map do |sample|
        scaled = [[sample.to_f, -1.0].max, 1.0].min * 32_767.0
        scaled.round
      end.pack("s<*")
    end
  end
end
