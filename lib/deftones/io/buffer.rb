# frozen_string_literal: true

require "open3"
require "tempfile"
require "timeout"

module Deftones
  module IO
    class Buffer
      include Enumerable

      attr_reader :samples, :channels, :sample_rate, :interpolation

      COMPRESSED_EXTENSIONS = %w[.mp3 .ogg .oga].freeze
      SAVEABLE_FORMATS = %i[wav mp3 ogg].freeze
      DEFAULT_CODEC_TIMEOUT = 30.0
      INTERPOLATION_MODES = %i[linear nearest cubic].freeze
      WAV_BIT_DEPTHS = [16, 24, 32].freeze

      class << self
        attr_accessor :codec_backend, :codec_timeout
      end

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

      def self.compressed_audio_available?
        return true if codec_backend&.respond_to?(:decode)
        return true if codec_backend&.respond_to?(:encode)

        send(:executable_available?, "ffmpeg") || send(:executable_available?, "afconvert")
      end

      class << self
        alias fromArray from_array
        alias fromUrl from_url
        alias compressedAudioAvailable compressed_audio_available?
      end

      def self.load(source)
        return load_io(source) if source.respond_to?(:read) && !source.is_a?(String)

        validate_path_string!(source, role: "audio source")
        extension = File.extname(source).downcase
        return load_wav(source) if extension == ".wav"
        return load_compressed(source, extension) if COMPRESSED_EXTENSIONS.include?(extension)

        raise Deftones::UnsupportedAudioFormatError, "Unsupported audio format: #{extension}"
      end

      def initialize(samples, channels:, sample_rate:, interpolation: :linear)
        @samples = samples.map(&:to_f)
        @channels = channels
        @sample_rate = sample_rate
        @interpolation = normalize_interpolation(interpolation)
        @disposed = false
        @mono_cache = nil
        @peak_cache = nil
        @rms_cache = nil
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
        return @mono_cache if @mono_cache

        @mono_cache = Array.new(frames) do |frame|
          offset = frame * @channels
          @samples[offset, @channels].sum / @channels.to_f
        end
      end

      def peak
        @peak_cache ||= @samples.map(&:abs).max || 0.0
      end

      def rms
        return 0.0 if @samples.empty?

        @rms_cache ||= Math.sqrt(@samples.sum { |sample| sample * sample } / @samples.length)
      end

      def clip_count(threshold = 1.0)
        limit = threshold.to_f.abs
        @samples.count { |sample| sample.abs >= limit }
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

      def interpolation=(value)
        @interpolation = normalize_interpolation(value)
      end

      def sample_at(frame_position, channel = 0, interpolation: @interpolation)
        return 0.0 if @samples.empty?

        clamped_position = Deftones::DSP::Helpers.clamp(frame_position.to_f, 0.0, [frames - 1, 0].max)
        channel_index = [channel, @channels - 1].min
        case normalize_interpolation(interpolation)
        when :nearest
          self[clamped_position.round, channel_index]
        when :cubic
          cubic_sample_at(clamped_position, channel_index)
        else
          linear_sample_at(clamped_position, channel_index)
        end
      end

      def sample_at_nearest(frame_position, channel = 0)
        sample_at(frame_position, channel, interpolation: :nearest)
      end

      def sample_at_cubic(frame_position, channel = 0)
        sample_at(frame_position, channel, interpolation: :cubic)
      end

      alias sampleAt sample_at
      alias sampleAtNearest sample_at_nearest
      alias sampleAtCubic sample_at_cubic

      def linear_sample_at(clamped_position, channel)
        lower = clamped_position.floor
        upper = [lower + 1, frames - 1].min
        fraction = clamped_position - lower
        lower_sample = self[lower, channel]
        upper_sample = self[upper, channel]
        Deftones::DSP::Helpers.lerp(lower_sample, upper_sample, fraction)
      end

      def cubic_sample_at(clamped_position, channel)
        base = clamped_position.floor
        fraction = clamped_position - base
        p0 = self[[base - 1, 0].max, channel]
        p1 = self[base, channel]
        p2 = self[[base + 1, frames - 1].min, channel]
        p3 = self[[base + 2, frames - 1].min, channel]
        a0 = (-0.5 * p0) + (1.5 * p1) - (1.5 * p2) + (0.5 * p3)
        a1 = p0 - (2.5 * p1) + (2.0 * p2) - (0.5 * p3)
        a2 = (-0.5 * p0) + (0.5 * p2)
        a3 = p1
        (((a0 * fraction) + a1) * fraction * fraction) + (a2 * fraction) + a3
      end

      def slice(start_frame, length)
        frame_count = [length.to_i, 0].max
        offset = start_frame.to_i * @channels
        subset = @samples.slice(offset, frame_count * @channels) || []
        self.class.new(subset, channels: @channels, sample_rate: @sample_rate)
      end

      def slice_seconds(start_time, duration)
        start_frame = (Deftones::Music::Time.parse(start_time) * @sample_rate).floor
        frame_count = (Deftones::Music::Time.parse(duration) * @sample_rate).ceil
        slice(start_frame, frame_count)
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

      def normalize_rms(target_rms = 0.2)
        return self.class.new(@samples, channels: @channels, sample_rate: @sample_rate) if rms.zero?

        scale = target_rms.to_f / rms
        self.class.new(@samples.map { |sample| sample * scale }, channels: @channels, sample_rate: @sample_rate)
      end

      def mixdown
        self.class.new(mono, channels: 1, sample_rate: @sample_rate)
      end

      def dispose
        @samples = []
        @mono_cache = nil
        @peak_cache = nil
        @rms_cache = nil
        @disposed = true
        self
      end

      alias numberOfChannels number_of_channels
      alias getChannelData get_channel_data
      alias toArray to_array
      alias sliceSeconds slice_seconds
      alias normalizeRms normalize_rms

      def save(target, format: nil, on_format_mismatch: :error, bit_depth: 16, dither: false, dither_rng: nil)
        if target.respond_to?(:write) && !target.is_a?(String)
          return save_io(target, format: format || :wav, bit_depth: bit_depth, dither: dither, dither_rng: dither_rng)
        end

        self.class.send(:validate_path_string!, target, role: "audio target")
        resolved_format = self.class.send(:resolve_save_format, target, format, on_format_mismatch: on_format_mismatch)
        raise Deftones::UnsupportedAudioFormatError, "Unsupported format: #{resolved_format}" unless SAVEABLE_FORMATS.include?(resolved_format)

        case resolved_format
        when :wav
          save_wav(target, bit_depth: bit_depth, dither: dither, dither_rng: dither_rng)
        when :mp3, :ogg
          save_compressed(target, resolved_format, bit_depth: bit_depth, dither: dither, dither_rng: dither_rng)
        end
        target
      end

      private

      def normalize_interpolation(value)
        normalized = value.to_sym
        return normalized if INTERPOLATION_MODES.include?(normalized)

        raise ArgumentError, "Unsupported interpolation mode: #{value}"
      end

      def save_io(io, format:, bit_depth:, dither:, dither_rng:)
        Tempfile.create(["deftones-buffer-save", ".#{format}"]) do |tempfile|
          tempfile.close
          save(tempfile.path, format: format, bit_depth: bit_depth, dither: dither, dither_rng: dither_rng)
          io.write(File.binread(tempfile.path))
        end
        io
      end

      def save_wav(path, bit_depth:, dither:, dither_rng:)
        self.class.send(:ensure_wav_backend!)
        normalized_bit_depth = self.class.send(:validate_wav_bit_depth, bit_depth)
        output_samples = dither ? dithered_samples(normalized_bit_depth, dither_rng) : @samples

        sample_buffer = Wavify::Core::SampleBuffer.new(
          output_samples,
          self.class.send(:wavify_work_format, @channels, @sample_rate)
        )
        Wavify::Codecs::Wav.write(
          path,
          sample_buffer,
          format: self.class.send(:wavify_wav_format, @channels, @sample_rate, normalized_bit_depth)
        )
      end

      def save_compressed(path, format, bit_depth:, dither:, dither_rng:)
        backend = self.class.send(:encoder_backend_for, format)
        raise Deftones::MissingCodecBackendError, self.class.send(:missing_encoder_message, format) unless backend

        Tempfile.create(["deftones-buffer-export", ".wav"]) do |tempfile|
          tempfile.close
          save_wav(tempfile.path, bit_depth: bit_depth, dither: dither, dither_rng: dither_rng)
          if self.class.send(:custom_codec_backend?, backend)
            backend.encode(tempfile.path, path, format: format, sample_rate: @sample_rate, channels: @channels)
            return
          end

          command = self.class.send(:encoder_command, backend, tempfile.path, path, format, @sample_rate, @channels)
          stdout, stderr, status = self.class.send(:capture_codec_command, *command)
          return if status.success?

          self.class.send(:raise_codec_command_error, "Failed to encode #{format}", command, stdout, stderr, status)
        end
      end

      def dithered_samples(bit_depth, rng)
        random = rng || Random
        step = 1.0 / ((2**(bit_depth - 1)) - 1)
        @samples.map do |sample|
          Deftones::DSP::Helpers.clamp(sample + ((random.rand - random.rand) * step), -1.0, 1.0)
        end
      end

      class << self
        private

        def load_wav(path)
          validate_path_string!(path, role: "WAV source")
          ensure_wav_backend!

          sample_buffer = Wavify::Codecs::Wav.read(path)
          float_buffer = sample_buffer.convert(wavify_work_format(sample_buffer.format.channels, sample_buffer.format.sample_rate))
          new(float_buffer.samples, channels: float_buffer.format.channels, sample_rate: float_buffer.format.sample_rate)
        rescue StandardError => error
          raise if error.is_a?(Deftones::MissingCodecBackendError)
          raise unless defined?(Wavify::Error) && error.is_a?(Wavify::Error)

          raise ArgumentError, "Failed to load WAV: #{error.message}"
        end

        def load_io(io)
          extension = io.respond_to?(:path) ? File.extname(io.path).downcase : ".wav"
          extension = ".wav" if extension.empty?
          Tempfile.create(["deftones-buffer-load", extension]) do |tempfile|
            tempfile.binmode
            tempfile.write(io.read)
            tempfile.close
            load(tempfile.path)
          end
        end

        def load_compressed(path, extension)
          validate_path_string!(path, role: "compressed audio source")
          backend = decoder_backend_for(extension)
          raise Deftones::MissingCodecBackendError, missing_decoder_message(extension) unless backend

          Tempfile.create(["deftones-buffer", ".wav"]) do |tempfile|
            tempfile.close
            if custom_codec_backend?(backend)
              backend.decode(path, tempfile.path, extension: extension)
              next load_wav(tempfile.path)
            end

            command = decoder_command(backend, path, tempfile.path)
            stdout, stderr, status = capture_codec_command(*command)
            next load_wav(tempfile.path) if status.success?

            raise_codec_command_error("Failed to decode #{extension}", command, stdout, stderr, status)
          end
        end

        def ensure_wav_backend!
          return if Deftones.wavify_available?

          raise Deftones::MissingCodecBackendError,
                "WAV codec backend is unavailable. Install the wavify gem to load or save WAV audio."
        end

        def wavify_work_format(channels, sample_rate)
          Wavify::Core::Format.new(
            channels: channels,
            sample_rate: sample_rate,
            bit_depth: 32,
            sample_format: :float
          )
        end

        def wavify_wav_format(channels, sample_rate, bit_depth)
          Wavify::Core::Format.new(
            channels: channels,
            sample_rate: sample_rate,
            bit_depth: bit_depth,
            sample_format: :pcm
          )
        end

        def validate_wav_bit_depth(bit_depth)
          normalized = bit_depth.to_i
          return normalized if WAV_BIT_DEPTHS.include?(normalized)

          raise ArgumentError, "Unsupported WAV bit depth: #{bit_depth}"
        end

        def decoder_backend_for(extension)
          return codec_backend if codec_backend&.respond_to?(:decode)
          return :ffmpeg if executable_available?("ffmpeg")
          return :afconvert if extension == ".mp3" && executable_available?("afconvert")

          nil
        end

        def encoder_backend_for(format)
          return codec_backend if codec_backend&.respond_to?(:encode)
          return :ffmpeg if executable_available?("ffmpeg")
          return :afconvert if format == :mp3 && executable_available?("afconvert")

          nil
        end

        def decoder_command(backend, input_path, output_path)
          case backend
          when :ffmpeg
            ["ffmpeg", "-v", "error", "-y", "-i", input_path, "-acodec", "pcm_f32le", "-f", "wav", output_path]
          when :afconvert
            ["afconvert", "-f", "WAVE", "-d", "LEI16", input_path, output_path]
          else
            raise ArgumentError, "Unknown decoder backend: #{backend}"
          end
        end

        def encoder_command(backend, input_path, output_path, format, sample_rate, channels)
          case backend
          when :ffmpeg
            container = format == :ogg ? "ogg" : format.to_s
            ["ffmpeg", "-v", "error", "-y", "-i", input_path, "-ar", sample_rate.to_s, "-ac", channels.to_s, "-f", container, output_path]
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

        def capture_codec_command(*command)
          Timeout.timeout(codec_timeout || DEFAULT_CODEC_TIMEOUT) do
            Open3.capture3(*command)
          end
        rescue Timeout::Error
          raise ArgumentError, "Codec command timed out after #{codec_timeout || DEFAULT_CODEC_TIMEOUT} seconds"
        end

        def custom_codec_backend?(backend)
          !backend.is_a?(Symbol)
        end

        def raise_codec_command_error(prefix, command, stdout, stderr, status)
          detail = [stderr, stdout].map(&:to_s).map(&:strip).reject(&:empty?).first || "unknown codec error"
          exit_status = status.respond_to?(:exitstatus) && status.exitstatus ? " (exit #{status.exitstatus})" : ""
          raise Deftones::CodecCommandError.new(
            "#{prefix}: #{detail}#{exit_status}",
            command: command,
            stdout: stdout,
            stderr: stderr,
            status: status
          )
        end

        def missing_decoder_message(extension)
          "No decoder available for #{extension}. Install ffmpeg to enable compressed audio loading."
        end

        def missing_encoder_message(format)
          "No encoder available for #{format}. Install ffmpeg to enable compressed audio export."
        end

        def resolve_save_format(path, format, on_format_mismatch:)
          extension = File.extname(path).downcase
          if format
            normalized = normalize_format(format)
            expected_extension = ".#{normalized}"
            if on_format_mismatch == :error && !extension.empty? && extension != expected_extension
              raise Deftones::UnsupportedAudioFormatError,
                    "Format #{normalized} does not match file extension #{extension}"
            end
            return normalized
          end

          return :mp3 if extension == ".mp3"
          return :ogg if COMPRESSED_EXTENSIONS.include?(extension)

          :wav
        end

        def normalize_format(format)
          normalized = format.to_sym
          return :ogg if normalized == :oga

          normalized
        end

        def validate_path_string!(path, role:)
          string = path.to_s
          raise ArgumentError, "#{role} path must not be empty" if string.empty?
          raise ArgumentError, "#{role} path contains a null byte" if string.include?("\0")

          true
        end
      end
    end
  end
end
