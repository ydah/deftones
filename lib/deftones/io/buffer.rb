# frozen_string_literal: true

module Deftones
  module IO
    class Buffer
      attr_reader :samples, :channels, :sample_rate

      def self.interleave(mono_samples, channels)
        return mono_samples.dup if channels == 1

        mono_samples.flat_map { |sample| Array.new(channels, sample) }
      end

      def initialize(samples, channels:, sample_rate:)
        @samples = samples.map(&:to_f)
        @channels = channels
        @sample_rate = sample_rate
      end

      def frames
        @samples.length / @channels
      end

      def duration
        frames.to_f / @sample_rate
      end

      def mono
        return @samples if @channels == 1

        Array.new(frames) do |frame|
          offset = frame * @channels
          @samples[offset, @channels].sum / @channels.to_f
        end
      end

      def peak
        @samples.map(&:abs).max || 0.0
      end

      def rms
        return 0.0 if @samples.empty?

        Math.sqrt(@samples.sum { |sample| sample * sample } / @samples.length)
      end

      def [](frame_index, channel = nil)
        return mono[frame_index] if channel.nil?

        @samples[(frame_index * @channels) + channel]
      end

      def save(path, format: :wav)
        raise ArgumentError, "Unsupported format: #{format}" unless format.to_sym == :wav

        pcm_data = @samples.map do |sample|
          (sample.clamp(-1.0, 1.0) * 32_767).round
        end.pack("s<*")

        byte_rate = @sample_rate * @channels * 2
        block_align = @channels * 2
        data_size = pcm_data.bytesize
        chunk_size = 36 + data_size

        header = [
          "RIFF", chunk_size, "WAVE",
          "fmt ", 16, 1, @channels, @sample_rate, byte_rate, block_align, 16,
          "data", data_size
        ].pack("A4VA4A4VvvVVvvA4V")

        File.binwrite(path, header + pcm_data)
        path
      end
    end
  end
end
