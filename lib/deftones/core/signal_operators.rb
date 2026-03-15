# frozen_string_literal: true

module Deftones
  module Core
    class BinarySignal < ComputedSignal
      attr_reader :other

      def initialize(input:, other:, units: nil, context: nil)
        super(input: input, units: units, context: context)
        @other = coerce_signal(other, units: @units)
      end

      def value_at(time)
        compute(@input.value_at(time), @other.value_at(time), time)
      end
    end

    class Add < BinarySignal
      def initialize(input:, addend:, units: nil, context: nil)
        super(input: input, other: addend, units: units, context: context)
      end

      def compute(left, right, _time)
        left + right
      end
    end

    class Subtract < BinarySignal
      def initialize(input:, subtrahend:, units: nil, context: nil)
        super(input: input, other: subtrahend, units: units, context: context)
      end

      def compute(left, right, _time)
        left - right
      end
    end

    class Multiply < BinarySignal
      def initialize(input:, factor:, units: nil, context: nil)
        super(input: input, other: factor, units: units, context: context)
      end

      def compute(left, right, _time)
        left * right
      end
    end

    class GreaterThan < BinarySignal
      def initialize(input:, threshold:, context: nil)
        super(input: input, other: threshold, units: :number, context: context)
      end

      def compute(left, right, _time)
        left > right ? 1.0 : 0.0
      end
    end

    class GreaterThanZero < GreaterThan
      def initialize(input:, context: nil)
        super(input: input, threshold: 0.0, context: context)
      end
    end

    class Negate < ComputedSignal
      def value_at(time)
        -@input.value_at(time)
      end
    end

    class Abs < ComputedSignal
      def value_at(time)
        @input.value_at(time).abs
      end
    end

    class Pow < ComputedSignal
      attr_reader :exponent

      def initialize(input:, exponent:, context: nil)
        super(input: input, units: :number, context: context)
        @exponent = coerce_signal(exponent, units: :number)
      end

      def value_at(time)
        exponentiate(@input.value_at(time), @exponent.value_at(time))
      end
    end

    class Scale < ComputedSignal
      attr_reader :min, :max

      def initialize(input:, min:, max:, context: nil)
        super(input: input, units: :number, context: context)
        @min = coerce_signal(min, units: :number)
        @max = coerce_signal(max, units: :number)
      end

      def value_at(time)
        min_value = @min.value_at(time)
        max_value = @max.value_at(time)

        min_value + ((max_value - min_value) * @input.value_at(time))
      end
    end

    class ScaleExp < Scale
      attr_reader :exponent

      def initialize(input:, min:, max:, exponent: 2.0, context: nil)
        super(input: input, min: min, max: max, context: context)
        @exponent = coerce_signal(exponent, units: :number)
      end

      def value_at(time)
        min_value = @min.value_at(time)
        max_value = @max.value_at(time)
        scaled = exponentiate(@input.value_at(time), @exponent.value_at(time))

        min_value + ((max_value - min_value) * scaled)
      end
    end

    class AudioToGain < ComputedSignal
      def value_at(time)
        @input.value_at(time)
      end
    end

    class GainToAudio < AudioToGain
    end

    class Zero < Signal
      def initialize(context: Deftones.context)
        super(value: 0.0, units: :number, context: context)
      end
    end
  end
end
