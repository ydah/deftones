# frozen_string_literal: true

module Deftones
  module Source
    class Oscillator < Core::Source
      GENERATORS = {
        sine: lambda { |phase|
          Math.sin(2.0 * Math::PI * phase)
        },
        square: lambda { |phase|
          phase < 0.5 ? 1.0 : -1.0
        },
        sawtooth: lambda { |phase|
          (2.0 * phase) - 1.0
        },
        triangle: lambda { |phase|
          (4.0 * (phase < 0.5 ? phase : 1.0 - phase)) - 1.0
        }
      }.freeze

      attr_reader :frequency
      attr_accessor :type

      def initialize(type: :sine, frequency: 440.0, phase: 0.0, context: Deftones.context)
        super(context: context)
        @type = normalize_type(type)
        @frequency = Core::Signal.new(value: frequency, units: :frequency, context: context)
        self.phase = phase
      end

      def phase
        @phase
      end

      def phase=(value)
        @phase = value.to_f % 1.0
      end

      def process(_input_buffer, num_frames, start_frame, _cache)
        generator = GENERATORS.fetch(normalize_type(@type))
        frequencies = @frequency.process(num_frames, start_frame)

        Array.new(num_frames) do |index|
          current_time = (start_frame + index).to_f / context.sample_rate
          next 0.0 unless active_at?(current_time)

          sample = generator.call(@phase)
          @phase = (@phase + (frequencies[index] / context.sample_rate)) % 1.0
          sample
        end
      end

      private

      def normalize_type(type)
        normalized = type.to_sym
        return normalized if GENERATORS.key?(normalized)

        raise ArgumentError, "Unsupported oscillator type: #{type}"
      end
    end
  end
end
