# frozen_string_literal: true

module Deftones
  module Core
    class EqualPowerGain < ComputedSignal
      def initialize(input:, context: nil)
        super(input: input, units: :number, context: context)
      end

      def value_at(time)
        Math.sin(@input.value_at(time).clamp(0.0, 1.0) * Math::PI * 0.5)
      end
    end

    class Modulo < BinarySignal
      def initialize(input:, modulus:, context: nil)
        super(input: input, other: modulus, units: :number, context: context)
      end

      def compute(left, right, _time)
        return 0.0 if right.zero?

        ((left % right) + right) % right
      end
    end

    class Normalize < ComputedSignal
      attr_reader :min, :max

      def initialize(input:, min:, max:, context: nil)
        super(input: input, units: :number, context: context)
        @min = coerce_signal(min, units: :number)
        @max = coerce_signal(max, units: :number)
      end

      def value_at(time)
        min_value = @min.value_at(time)
        max_value = @max.value_at(time)
        span = max_value - min_value
        return 0.0 if span.zero?

        (@input.value_at(time) - min_value) / span
      end
    end

    class WaveShaper < ComputedSignal
      def initialize(input:, curve: nil, mapping: nil, context: nil, &block)
        super(input: input, units: :number, context: context)
        @mapping = mapping || block
        @curve = normalize_curve(curve)
        raise ArgumentError, "curve or mapping is required" unless @mapping || @curve
      end

      def value_at(time)
        sample = @input.value_at(time)
        return @mapping.call(sample, time) if @mapping

        sample_curve(sample)
      end

      private

      def normalize_curve(curve)
        return if curve.nil?

        values = curve.to_a.map(&:to_f)
        raise ArgumentError, "curve must contain at least two points" if values.length < 2

        values.freeze
      end

      def sample_curve(sample)
        position = ((sample.clamp(-1.0, 1.0) + 1.0) * 0.5) * (@curve.length - 1)
        index = position.floor
        upper_index = [index + 1, @curve.length - 1].min
        lower = @curve[index]
        upper = @curve[upper_index]

        lower + ((upper - lower) * (position - index))
      end
    end
  end
end
