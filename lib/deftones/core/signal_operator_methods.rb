# frozen_string_literal: true

module Deftones
  module Core
    module SignalOperatorMethods
      def add(value)
        Add.new(input: self, addend: value, context: context)
      end

      def subtract(value)
        Subtract.new(input: self, subtrahend: value, context: context)
      end

      def multiply(value)
        Multiply.new(input: self, factor: value, context: context)
      end

      def negate
        Negate.new(input: self, context: context)
      end

      def abs
        Abs.new(input: self, context: context)
      end

      def equal_power_gain
        EqualPowerGain.new(input: self, context: context)
      end

      def greater_than(value)
        GreaterThan.new(input: self, threshold: value, context: context)
      end

      def greater_than_zero
        GreaterThanZero.new(input: self, context: context)
      end

      def modulo(value)
        Modulo.new(input: self, modulus: value, context: context)
      end

      def normalize(min, max)
        Normalize.new(input: self, min: min, max: max, context: context)
      end

      def scale(min, max)
        Scale.new(input: self, min: min, max: max, context: context)
      end

      def scale_exp(min, max, exponent: 2.0)
        ScaleExp.new(input: self, min: min, max: max, exponent: exponent, context: context)
      end

      def pow(exponent)
        Pow.new(input: self, exponent: exponent, context: context)
      end

      def wave_shaper(curve = nil, mapping: nil, &block)
        WaveShaper.new(input: self, curve: curve, mapping: mapping, context: context, &block)
      end

      alias waveshaper wave_shaper

      def to_audio
        GainToAudio.new(input: self, context: context)
      end

      def to_gain
        AudioToGain.new(input: self, context: context)
      end
    end
  end
end
