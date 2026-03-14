# frozen_string_literal: true

module Deftones
  module IO
    class Buffer
      include Enumerable

      attr_reader :samples, :channels, :sample_rate

      WAV_HEADER_SIZE = 44

      def self.interleave(mono_samples, channels)
        return mono_samples.dup if channels == 1

        mono_samples.flat_map { |sample| Array.new(channels, sample) }
      end

      def self.from_mono(samples, channels: 1, sample_rate: Context::DEFAULT_SAMPLE_RATE)
        interleaved = channels == 1 ? samples : interleave(samples, channels)
        new(interleaved, channels: channels, sample_rate: sample_rate)
      end

      def self.load(path)
        extension = File.extname(path).downcase
        return load_wav(path) if extension == ".wav"

        raise ArgumentError, "Unsupported audio format: #{extension}"
      end

      def initialize(samples, channels:, sample_rate:)
        @samples = samples.map(&:to_f)
        @channels = channels
        @sample_rate = sample_rate
      end

      def each(&block)
        return enum_for(:each) unless block

        mono.each(&block)
      end

      def each_frame
        return enum_for(:each_frame) unless block_given?

        frames.times do |frame_index|
          yield frame(frame_index)
        end
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

      def frame(frame_index)
        offset = frame_index * @channels
        @samples[offset, @channels]
      end

      def sample_at(frame_position, channel = 0)
        return 0.0 if @samples.empty?

        clamped_position = Deftones::DSP::Helpers.clamp(frame_position.to_f, 0.0, [frames - 1, 0].max)
        lower = clamped_position.floor
        upper = [lower + 1, frames - 1].min
        fraction = clamped_position - lower
        lower_sample = self[lower, [channel, @channels - 1].min]
        upper_sample = self[upper, [channel, @channels - 1].min]
        Deftones::DSP::Helpers.lerp(lower_sample, upper_sample, fraction)
      end

      def slice(start_frame, length)
        frame_count = [length.to_i, 0].max
        offset = start_frame.to_i * @channels
        subset = @samples.slice(offset, frame_count * @channels) || []
        self.class.new(subset, channels: @channels, sample_rate: @sample_rate)
      end

      def reverse
        reversed_frames = each_frame.to_a.reverse.flatten
        self.class.new(reversed_frames, channels: @channels, sample_rate: @sample_rate)
      end

      def normalize(target_peak = 0.99)
        return self.class.new(@samples, channels: @channels, sample_rate: @sample_rate) if peak.zero?

        scale = target_peak.to_f / peak
        self.class.new(@samples.map { |sample| sample * scale }, channels: @channels, sample_rate: @sample_rate)
      end

      def mixdown
        self.class.new(mono, channels: 1, sample_rate: @sample_rate)
      end

      def save(path, format: :wav)
        raise ArgumentError, "Unsupported format: #{format}" unless format.to_sym == :wav

        save_wav(path)
        path
      end

      private

      def save_wav(path)
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
      end

      class << self
        private

        def load_wav(path)
          file = File.binread(path)
          raise ArgumentError, "Invalid WAV header" unless file.start_with?("RIFF") && file[8, 4] == "WAVE"

          channels, sample_rate, bits_per_sample, data_offset, data_size = parse_wav_chunks(file)
          bytes = file.byteslice(data_offset, data_size)
          samples =
            case bits_per_sample
            when 16
              bytes.unpack("s<*").map { |sample| sample / 32_768.0 }
            when 32
              bytes.unpack("e*")
            else
              raise ArgumentError, "Unsupported WAV bit depth: #{bits_per_sample}"
            end

          new(samples, channels: channels, sample_rate: sample_rate)
        end

        def parse_wav_chunks(file)
          offset = 12
          fmt_chunk = nil
          data_offset = nil
          data_size = nil

          while offset < file.bytesize
            chunk_id = file[offset, 4]
            chunk_size = file[offset + 4, 4].unpack1("V")
            chunk_data_offset = offset + 8

            case chunk_id
            when "fmt "
              fmt_chunk = file[chunk_data_offset, chunk_size]
            when "data"
              data_offset = chunk_data_offset
              data_size = chunk_size
            end

            offset = chunk_data_offset + chunk_size
            offset += 1 if offset.odd?
          end

          raise ArgumentError, "Missing fmt chunk" unless fmt_chunk
          raise ArgumentError, "Missing data chunk" unless data_offset && data_size

          _, channels, sample_rate, = fmt_chunk.unpack("v v V")
          bits_per_sample = fmt_chunk[14, 2].unpack1("v")
          [channels, sample_rate, bits_per_sample, data_offset, data_size]
        end
      end
    end
  end
end
