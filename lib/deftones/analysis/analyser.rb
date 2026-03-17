# frozen_string_literal: true

module Deftones
  module Analysis
    class Analyser < Core::AudioNode
      TYPES = %i[fft waveform].freeze
      RETURN_TYPES = %i[float byte].freeze

      attr_reader :size, :type, :return_type, :min_decibels, :max_decibels
      attr_accessor :normal_range

      def initialize(size: 1024, type: :fft, return_type: :float, smoothing: 0.8,
                     normal_range: false, min_decibels: -100.0, max_decibels: 0.0,
                     context: Deftones.context)
        super(context: context)
        @type = normalize_type(type)
        @return_type = normalize_return_type(return_type)
        @normal_range = !!normal_range
        @min_decibels = min_decibels.to_f
        @max_decibels = max_decibels.to_f
        self.smoothing = smoothing
        self.size = size
      end

      def waveform
        Waveform::Snapshot.new(@recent_samples.dup)
      end

      def fft
        FFT.magnitudes(@recent_samples)
      end

      def size=(value)
        @size = [value.to_i, 1].max
        recent = @recent_samples || []
        padding = [@size - recent.length, 0].max
        @recent_samples = Array.new(padding, 0.0) + recent.last(@size)
        @smoothed_waveform = @recent_samples.dup
        @smoothed_fft = FFT.decibels(@recent_samples, floor: @min_decibels)
      end

      def type=(value)
        @type = normalize_type(value)
      end

      def return_type=(value)
        @return_type = normalize_return_type(value)
      end

      def smoothing
        @smoothing
      end

      def smoothing=(value)
        @smoothing = Deftones::DSP::Helpers.clamp(value.to_f, 0.0, 1.0)
      end

      def min_decibels=(value)
        @min_decibels = value.to_f
        @smoothed_fft = FFT.decibels(@recent_samples, floor: @min_decibels)
      end

      def max_decibels=(value)
        @max_decibels = value.to_f
      end

      def get_value
        if @type == :waveform
          format_waveform_values(@smoothed_waveform)
        else
          format_fft_values(@smoothed_fft)
        end
      end

      def multichannel_process?
        true
      end

      def process(input_block, num_frames, _start_frame, _cache)
        analysed = input_block.mono.first(num_frames)
        @recent_samples.concat(analysed)
        @recent_samples = @recent_samples.last(@size)
        @smoothed_waveform = smooth_values(@smoothed_waveform, @recent_samples)
        @smoothed_fft = smooth_values(@smoothed_fft, FFT.decibels(@recent_samples, floor: @min_decibels))
        input_block
      end

      alias getValue get_value
      alias returnType return_type
      alias normalRange normal_range
      alias minDecibels min_decibels
      alias maxDecibels max_decibels

      def returnType=(value)
        self.return_type = value
      end

      def normalRange=(value)
        self.normal_range = value
      end

      def minDecibels=(value)
        self.min_decibels = value
      end

      def maxDecibels=(value)
        self.max_decibels = value
      end

      private

      def normalize_type(value)
        normalized = value.to_s.downcase.to_sym
        raise ArgumentError, "Unsupported analyser type: #{value}" unless TYPES.include?(normalized)

        normalized
      end

      def normalize_return_type(value)
        normalized = value.to_s.downcase.to_sym
        raise ArgumentError, "Unsupported analyser return type: #{value}" unless RETURN_TYPES.include?(normalized)

        normalized
      end

      def smooth_values(previous, current)
        return current.dup if @smoothing.zero?

        previous.zip(current).map do |prior, sample|
          (prior.to_f * @smoothing) + (sample.to_f * (1.0 - @smoothing))
        end
      end

      def format_waveform_values(values)
        if @return_type == :byte
          values.map { |sample| (((Deftones::DSP::Helpers.clamp(sample, -1.0, 1.0) + 1.0) * 0.5) * 255.0).round }
        elsif @normal_range
          values.map { |sample| Deftones::DSP::Helpers.clamp((sample + 1.0) * 0.5, 0.0, 1.0) }
        else
          values.map { |sample| Deftones::DSP::Helpers.clamp(sample, -1.0, 1.0) }
        end
      end

      def format_fft_values(values)
        return values.map { |value| scale_to_byte_range(value) } if @return_type == :byte
        return values.map { |value| scale_to_normal_range(value) } if @normal_range

        values.map { |value| Deftones::DSP::Helpers.clamp(value, @min_decibels, @max_decibels) }
      end

      def scale_to_normal_range(value)
        return 0.0 if @max_decibels <= @min_decibels

        Deftones::DSP::Helpers.clamp((value - @min_decibels) / (@max_decibels - @min_decibels), 0.0, 1.0)
      end

      def scale_to_byte_range(value)
        (scale_to_normal_range(value) * 255.0).round
      end
    end
  end
end
