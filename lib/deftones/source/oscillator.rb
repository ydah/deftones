# frozen_string_literal: true

module Deftones
  module Source
    class Oscillator < Core::Source
      TYPES = %i[sine square sawtooth triangle].freeze
      GENERATORS = {
        sine: ->(phase) { Math.sin(2.0 * Math::PI * phase) },
        square: ->(phase) { phase < 0.5 ? 1.0 : -1.0 },
        sawtooth: ->(phase) { (2.0 * phase) - 1.0 },
        triangle: ->(phase) { (4.0 * (phase < 0.5 ? phase : 1.0 - phase)) - 1.0 }
      }.freeze

      class << self
        def sample(type, phase, phase_increment = 0.0)
          case type
          when :sine
            Math.sin(2.0 * Math::PI * phase)
          when :square
            bandlimited_square(phase, phase_increment)
        when :sawtooth
          bandlimited_sawtooth(phase, phase_increment)
        when :triangle
          bandlimited_triangle(phase, phase_increment)
        end
        end

        private

        def bandlimited_square(phase, phase_increment)
          sample = phase < 0.5 ? 1.0 : -1.0
          sample += poly_blep(phase, phase_increment)
          sample -= poly_blep((phase + 0.5) % 1.0, phase_increment)
          sample
        end

        def bandlimited_sawtooth(phase, phase_increment)
          ((2.0 * phase) - 1.0) - poly_blep(phase, phase_increment)
        end

        def bandlimited_triangle(phase, phase_increment)
          return naive_triangle(phase) unless phase_increment.positive?

          max_harmonic = (0.5 / phase_increment.abs).floor
          return naive_triangle(phase) if max_harmonic < 1

          sum = 0.0
          harmonic = 1
          while harmonic <= max_harmonic
            sum += Math.cos(2.0 * Math::PI * harmonic * phase) / (harmonic * harmonic)
            harmonic += 2
          end
          -(8.0 / (Math::PI * Math::PI)) * sum
        end

        def naive_triangle(phase)
          (4.0 * (phase < 0.5 ? phase : 1.0 - phase)) - 1.0
        end

        def poly_blep(phase, phase_increment)
          increment = [phase_increment.abs, 1.0e-9].max
          return poly_blep_start(phase / increment) if phase < increment
          return poly_blep_end((phase - 1.0) / increment) if phase > 1.0 - increment

          0.0
        end

        def poly_blep_start(t)
          (t + t) - (t * t) - 1.0
        end

        def poly_blep_end(t)
          (t * t) + (t + t) + 1.0
        end
      end

      attr_reader :detune, :frequency, :type

      def initialize(type: :sine, frequency: 440.0, detune: 0.0, phase: 0.0, context: Deftones.context)
        super(context: context)
        self.type = type
        @frequency = Core::Signal.new(value: frequency, units: :frequency, context: context)
        @detune = Core::Signal.new(value: detune, units: :number, context: context)
        self.phase = phase
      end

      def detune=(value)
        @detune.value = value
      end

      def phase
        @phase
      end

      def phase=(value)
        @phase = value.to_f % 1.0
      end

      def type=(value)
        @type = normalize_type(value)
      end

      def process(_input_buffer, num_frames, start_frame, _cache)
        oscillator_type = normalize_type(@type)
        frequencies = @frequency.process(num_frames, start_frame)
        detunes = @detune.process(num_frames, start_frame)

        Array.new(num_frames) do |index|
          current_time = (start_frame + index).to_f / context.sample_rate
          next 0.0 unless active_at?(current_time)

          frequency = frequencies[index] * detune_ratio(detunes[index])
          phase_increment = frequency / context.sample_rate
          sample = sample_for(oscillator_type, @phase, phase_increment)
          @phase = (@phase + phase_increment) % 1.0
          sample
        end
      end

      private

      def sample_for(type, phase, phase_increment)
        Oscillator.sample(type, phase, phase_increment)
      end

      def detune_ratio(cents)
        2.0**(cents.to_f / 1200.0)
      end

      def normalize_type(type)
        normalized = type.to_sym
        return normalized if TYPES.include?(normalized)

        raise ArgumentError, "Unsupported oscillator type: #{type}"
      end
    end
  end
end
