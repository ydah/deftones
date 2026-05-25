# frozen_string_literal: true

module Deftones
  class OfflineContext < Context
    RenderResult = Struct.new(:buffer, :metadata, keyword_init: true)
    class RenderCancelled < Deftones::Error; end

    attr_reader :channels, :current_frame, :duration, :last_render_metadata, :total_frames

    def initialize(duration:, channels: 2, sample_rate: DEFAULT_SAMPLE_RATE,
                   buffer_size: DEFAULT_BUFFER_SIZE, transport: nil, draw: nil)
      super(sample_rate: sample_rate, buffer_size: buffer_size, channels: channels, autostart: false,
            transport: transport, draw: draw)
      @duration = duration.to_f
      @total_frames = (@duration * sample_rate).ceil
      @current_frame = 0
      @rendering = false
      @last_render_metadata = nil
    end

    def current_time
      @current_frame.to_f / sample_rate
    end

    def state
      "suspended"
    end

    def render(seed: nil, metadata: false, progress: nil, cancel: nil)
      samples = Array.new(@total_frames * @channels, 0.0)

      render_each_block(seed: seed, progress: progress, cancel: cancel) do |block, start_frame|
        interleaved = block.fit_channels(@channels).interleaved
        start_index = start_frame * @channels

        samples[start_index, interleaved.length] = interleaved
      end

      buffer = IO::Buffer.new(samples, channels: @channels, sample_rate: sample_rate)
      @last_render_metadata = metadata_for(buffer)
      return RenderResult.new(buffer: buffer, metadata: @last_render_metadata) if metadata

      buffer
    end

    def render_with_metadata(**options)
      render(**options, metadata: true)
    end

    def render_each_block(seed: nil, progress: nil, cancel: nil)
      return enum_for(:render_each_block) unless block_given?

      with_render_state(seed: seed) do
        frames_processed = 0

        while frames_processed < @total_frames
          raise RenderCancelled, "render cancelled" if cancel&.call(frames_processed.to_f / @total_frames)

          chunk_frames = [buffer_size, @total_frames - frames_processed].min
          @current_frame = frames_processed
          advance_schedulers(frames_processed, chunk_frames)
          yield render_block_frames(chunk_frames, frames_processed).fit_channels(@channels), frames_processed
          frames_processed += chunk_frames
          progress&.call(frames_processed.to_f / @total_frames)
        end

        @current_frame = @total_frames
      end

      self
    end

    alias renderEachBlock render_each_block
    alias renderWithMetadata render_with_metadata

    def render_to_file(path, format: nil, streaming: false, bit_depth: 16, dither: false, dither_rng: nil,
                       **render_options)
      if streaming
        return stream_to_file(path, format: format, bit_depth: bit_depth, dither: dither, dither_rng: dither_rng,
                                    **render_options)
      end

      rendered_buffer = render(**render_options)
      buffer = rendered_buffer.respond_to?(:buffer) ? rendered_buffer.buffer : rendered_buffer
      buffer.save(path, format: format, bit_depth: bit_depth, dither: dither, dither_rng: dither_rng)
      rendered_buffer
    end

    private

    def with_render_state(seed: nil)
      previous_frame = @current_frame
      previous_rendering = @rendering
      previous_seed = seed ? srand(seed) : nil
      @rendering = true
      @current_frame = 0
      yield
    ensure
      srand(previous_seed) if seed
      @current_frame = previous_frame
      @rendering = previous_rendering
    end

    def advance_schedulers(start_frame, chunk_frames)
      window_start = start_frame.to_f / sample_rate
      window_end = (start_frame + chunk_frames).to_f / sample_rate
      transport.prepare_render_window(window_start, window_end)
      draw.advance_to(window_end)
      Deftones.transport.prepare_render_window(window_start, window_end) unless Deftones.transport.equal?(transport)
      Deftones.draw.advance_to(window_end) unless Deftones.draw.equal?(draw)
    end

    def stream_to_file(path, format: nil, bit_depth:, dither:, dither_rng:, **render_options)
      resolved_format = format || File.extname(path).delete_prefix(".").downcase.to_sym
      resolved_format = :wav if resolved_format.nil? || resolved_format == :""
      raise UnsupportedAudioFormatError, "Streaming render only supports WAV output" unless resolved_format.to_sym == :wav
      normalized_bit_depth = validate_wav_bit_depth(bit_depth)

      File.open(path, "wb") do |file|
        file.write(wav_header(normalized_bit_depth))
        render_each_block(**render_options) do |block, _start_frame|
          file.write(pcm_payload(block.fit_channels(@channels).interleaved,
                                 bit_depth: normalized_bit_depth,
                                 dither: dither,
                                 dither_rng: dither_rng))
        end
      end

      path
    end

    def metadata_for(buffer)
      {
        duration: duration,
        frames: total_frames,
        channels: channels,
        sample_rate: sample_rate,
        peak: buffer.peak,
        rms: buffer.rms,
        clip_count: buffer.clip_count
      }
    end

    def wav_header(bit_depth)
      bytes_per_sample = bit_depth / 8
      data_size = @total_frames * @channels * bytes_per_sample
      byte_rate = sample_rate * @channels * bytes_per_sample
      block_align = @channels * bytes_per_sample

      "RIFF" \
        + [36 + data_size].pack("V") \
        + "WAVEfmt " \
        + [16, 1, @channels, sample_rate, byte_rate, block_align, bit_depth].pack("VvvVVvv") \
        + "data" \
        + [data_size].pack("V")
    end

    def pcm_payload(samples, bit_depth:, dither:, dither_rng:)
      quantized = samples.map { |sample| quantize_pcm(sample, bit_depth, dither: dither, dither_rng: dither_rng) }

      case bit_depth
      when 16 then quantized.pack("s<*")
      when 24 then quantized.map { |value| [value & 0xFFFFFF].pack("V")[0, 3] }.join
      when 32 then quantized.pack("l<*")
      end
    end

    def quantize_pcm(sample, bit_depth, dither:, dither_rng:)
      max = (2**(bit_depth - 1)) - 1
      min = -(2**(bit_depth - 1))
      value = dither ? dither_sample(sample, bit_depth, dither_rng) : sample.to_f
      scaled = Deftones::DSP::Helpers.clamp(value, -1.0, 1.0) * max
      Deftones::DSP::Helpers.clamp(scaled.round, min, max)
    end

    def dither_sample(sample, bit_depth, rng)
      random = rng || Random
      step = 1.0 / ((2**(bit_depth - 1)) - 1)
      sample.to_f + ((random.rand - random.rand) * step)
    end

    def validate_wav_bit_depth(bit_depth)
      normalized = bit_depth.to_i
      return normalized if IO::Buffer::WAV_BIT_DEPTHS.include?(normalized)

      raise ArgumentError, "Unsupported WAV bit depth: #{bit_depth}"
    end
  end
end
