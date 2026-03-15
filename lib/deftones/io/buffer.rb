# frozen_string_literal: true

require "open3"
require "tempfile"

module Deftones
  module IO
    class Buffer
      include Enumerable

      attr_reader :samples, :channels, :sample_rate

      COMPRESSED_EXTENSIONS = %w[.mp3 .ogg .oga].freeze
      SAVEABLE_FORMATS = %i[wav mp3 ogg].freeze

      def self.interleave(mono_samples, channels)
        return mono_samples.dup if channels == 1

        mono_samples.flat_map { |sample| Array.new(channels, sample) }
      end

      def self.from_mono(samples, channels: 1, sample_rate: Context::DEFAULT_SAMPLE_RATE)
        interleaved = channels == 1 ? samples : interleave(samples, channels)
        new(interleaved, channels: channels, sample_rate: sample_rate)
      end

      def self.from_array(samples, sample_rate: Context::DEFAULT_SAMPLE_RATE, channels: nil)
        if samples.first.is_a?(Array)
          channel_count = channels || samples.length
          frame_count = samples.map(&:length).max || 0
          interleaved = Array.new(frame_count * channel_count, 0.0)

          frame_count.times do |frame_index|
            channel_count.times do |channel_index|
              source_channel = samples[channel_index] || []
              interleaved[(frame_index * channel_count) + channel_index] = source_channel[frame_index].to_f
            end
          end

          new(interleaved, channels: channel_count, sample_rate: sample_rate)
        else
          from_mono(samples, channels: channels || 1, sample_rate: sample_rate)
        end
      end

      def self.from_url(path)
        load(path)
      end

      def self.loaded
        true
      end

      class << self
        alias fromArray from_array
        alias fromUrl from_url
      end

      def self.load(path)
        extension = File.extname(path).downcase
        return load_wav(path) if extension == ".wav"
        return load_compressed(path, extension) if COMPRESSED_EXTENSIONS.include?(extension)

        raise ArgumentError, "Unsupported audio format: #{extension}"
      end

      def initialize(samples, channels:, sample_rate:)
        @samples = samples.map(&:to_f)
        @channels = channels
        @sample_rate = sample_rate
        @disposed = false
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

      def length
        frames
      end

      def loaded?
        !@disposed
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

      def number_of_channels
        @channels
      end

      def get_channel_data(channel)
        channel_index = channel.to_i
        raise ArgumentError, "channel is out of range" if channel_index.negative? || channel_index >= @channels

        Array.new(frames) { |frame_index| self[frame_index, channel_index] }
      end

      def to_array
        Array.new(@channels) { |channel_index| get_channel_data(channel_index) }
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

      def dispose
        @samples = []
        @disposed = true
        self
      end

      alias numberOfChannels number_of_channels
      alias getChannelData get_channel_data
      alias toArray to_array

      def save(path, format: nil)
        resolved_format = self.class.send(:resolve_save_format, path, format)
        raise ArgumentError, "Unsupported format: #{resolved_format}" unless SAVEABLE_FORMATS.include?(resolved_format)

        case resolved_format
        when :wav
          save_wav(path)
        when :mp3, :ogg
          save_compressed(path, resolved_format)
        end
        path
      end

      private

      def save_wav(path)
        sample_buffer = Wavify::Core::SampleBuffer.new(
          @samples,
          self.class.send(:wavify_work_format, @channels, @sample_rate)
        )
        Wavify::Codecs::Wav.write(
          path,
          sample_buffer,
          format: self.class.send(:wavify_wav_format, @channels, @sample_rate)
        )
      end

      def save_compressed(path, format)
        backend = self.class.send(:encoder_backend_for, format)
        raise ArgumentError, self.class.send(:missing_encoder_message, format) unless backend

        Tempfile.create(["deftones-buffer-export", ".wav"]) do |tempfile|
          tempfile.close
          save_wav(tempfile.path)
          stdout, stderr, status = Open3.capture3(*self.class.send(:encoder_command, backend, tempfile.path, path, format))
          return if status.success?

          message = [stderr, stdout].map(&:strip).reject(&:empty?).first || "unknown encoder error"
          raise ArgumentError, "Failed to encode #{format}: #{message}"
        end
      end

      class << self
        private

        def load_wav(path)
          sample_buffer = Wavify::Codecs::Wav.read(path)
          float_buffer = sample_buffer.convert(wavify_work_format(sample_buffer.format.channels, sample_buffer.format.sample_rate))
          new(float_buffer.samples, channels: float_buffer.format.channels, sample_rate: float_buffer.format.sample_rate)
        rescue Wavify::Error => error
          raise ArgumentError, "Failed to load WAV: #{error.message}"
        end

        def load_compressed(path, extension)
          backend = decoder_backend_for(extension)
          raise ArgumentError, missing_decoder_message(extension) unless backend

          Tempfile.create(["deftones-buffer", ".wav"]) do |tempfile|
            tempfile.close
            stdout, stderr, status = Open3.capture3(*decoder_command(backend, path, tempfile.path))
            next load_wav(tempfile.path) if status.success?

            message = [stderr, stdout].map(&:strip).reject(&:empty?).first || "unknown decoder error"
            raise ArgumentError, "Failed to decode #{extension}: #{message}"
          end
        end

        def wavify_work_format(channels, sample_rate)
          Wavify::Core::Format.new(
            channels: channels,
            sample_rate: sample_rate,
            bit_depth: 32,
            sample_format: :float
          )
        end

        def wavify_wav_format(channels, sample_rate)
          Wavify::Core::Format.new(
            channels: channels,
            sample_rate: sample_rate,
            bit_depth: 16,
            sample_format: :pcm
          )
        end

        def decoder_backend_for(extension)
          return :ffmpeg if executable_available?("ffmpeg")
          return :afconvert if extension == ".mp3" && executable_available?("afconvert")

          nil
        end

        def encoder_backend_for(format)
          return :ffmpeg if executable_available?("ffmpeg")
          return :afconvert if format == :mp3 && executable_available?("afconvert")

          nil
        end

        def decoder_command(backend, input_path, output_path)
          case backend
          when :ffmpeg
            ["ffmpeg", "-v", "error", "-y", "-i", input_path, "-f", "wav", output_path]
          when :afconvert
            ["afconvert", "-f", "WAVE", "-d", "LEI16", input_path, output_path]
          else
            raise ArgumentError, "Unknown decoder backend: #{backend}"
          end
        end

        def encoder_command(backend, input_path, output_path, format)
          case backend
          when :ffmpeg
            container = format == :ogg ? "ogg" : format.to_s
            ["ffmpeg", "-v", "error", "-y", "-i", input_path, "-f", container, output_path]
          when :afconvert
            raise ArgumentError, "afconvert only supports mp3 export" unless format == :mp3

            ["afconvert", "-f", "MPG3", "-d", ".mp3", input_path, output_path]
          else
            raise ArgumentError, "Unknown encoder backend: #{backend}"
          end
        end

        def executable_available?(name)
          ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? do |directory|
            executable = File.join(directory, name)
            File.file?(executable) && File.executable?(executable)
          end
        end

        def missing_decoder_message(extension)
          "No decoder available for #{extension}. Install ffmpeg to enable compressed audio loading."
        end

        def missing_encoder_message(format)
          "No encoder available for #{format}. Install ffmpeg to enable compressed audio export."
        end

        def resolve_save_format(path, format)
          return normalize_format(format) if format

          extension = File.extname(path).downcase
          return :mp3 if extension == ".mp3"
          return :ogg if COMPRESSED_EXTENSIONS.include?(extension)

          :wav
        end

        def normalize_format(format)
          normalized = format.to_sym
          return :ogg if normalized == :oga

          normalized
        end
      end
    end
  end
end
