# frozen_string_literal: true

module Deftones
  module DSP
    class Biquad
      TYPES = %i[lowpass highpass bandpass notch allpass peaking lowshelf highshelf].freeze

      def initialize
        reset!
        @coefficients = [1.0, 0.0, 0.0, 0.0, 0.0]
      end

      def update(type:, frequency:, q:, gain_db:, sample_rate:)
        raise ArgumentError, "Unsupported filter type: #{type}" unless TYPES.include?(type)

        normalized_frequency = Helpers.clamp(frequency.to_f, 10.0, (sample_rate / 2.0) - 10.0)
        omega = (2.0 * Math::PI * normalized_frequency) / sample_rate
        sin_omega = Math.sin(omega)
        cos_omega = Math.cos(omega)
        alpha = sin_omega / (2.0 * [q.to_f, 0.001].max)
        a = 10.0**(gain_db.to_f / 40.0)

        b0, b1, b2, a0, a1, a2 =
          case type
          when :lowpass
            lowpass_coefficients(cos_omega, alpha)
          when :highpass
            highpass_coefficients(cos_omega, alpha)
          when :bandpass
            [alpha, 0.0, -alpha, 1.0 + alpha, -2.0 * cos_omega, 1.0 - alpha]
          when :notch
            [1.0, -2.0 * cos_omega, 1.0, 1.0 + alpha, -2.0 * cos_omega, 1.0 - alpha]
          when :allpass
            [1.0 - alpha, -2.0 * cos_omega, 1.0 + alpha, 1.0 + alpha, -2.0 * cos_omega, 1.0 - alpha]
          when :peaking
            peaking_coefficients(cos_omega, alpha, a)
          when :lowshelf
            shelf_coefficients(:low, cos_omega, sin_omega, a)
          when :highshelf
            shelf_coefficients(:high, cos_omega, sin_omega, a)
          end

        @coefficients = normalize(b0, b1, b2, a0, a1, a2)
      end

      def process_sample(sample)
        b0, b1, b2, a1, a2 = @coefficients
        output = (b0 * sample) + (b1 * @x1) + (b2 * @x2) - (a1 * @y1) - (a2 * @y2)
        @x2 = @x1
        @x1 = sample
        @y2 = @y1
        @y1 = output
        output
      end

      def reset!
        @x1 = 0.0
        @x2 = 0.0
        @y1 = 0.0
        @y2 = 0.0
      end

      private

      def lowpass_coefficients(cos_omega, alpha)
        [
          (1.0 - cos_omega) / 2.0,
          1.0 - cos_omega,
          (1.0 - cos_omega) / 2.0,
          1.0 + alpha,
          -2.0 * cos_omega,
          1.0 - alpha
        ]
      end

      def highpass_coefficients(cos_omega, alpha)
        [
          (1.0 + cos_omega) / 2.0,
          -(1.0 + cos_omega),
          (1.0 + cos_omega) / 2.0,
          1.0 + alpha,
          -2.0 * cos_omega,
          1.0 - alpha
        ]
      end

      def peaking_coefficients(cos_omega, alpha, amplitude)
        [
          1.0 + (alpha * amplitude),
          -2.0 * cos_omega,
          1.0 - (alpha * amplitude),
          1.0 + (alpha / amplitude),
          -2.0 * cos_omega,
          1.0 - (alpha / amplitude)
        ]
      end

      def shelf_coefficients(kind, cos_omega, sin_omega, amplitude)
        sqrt_a = Math.sqrt(amplitude)
        alpha = sin_omega / Math.sqrt(2.0)
        common = 2.0 * sqrt_a * alpha

        if kind == :low
          [
            amplitude * ((amplitude + 1.0) - ((amplitude - 1.0) * cos_omega) + common),
            2.0 * amplitude * ((amplitude - 1.0) - ((amplitude + 1.0) * cos_omega)),
            amplitude * ((amplitude + 1.0) - ((amplitude - 1.0) * cos_omega) - common),
            (amplitude + 1.0) + ((amplitude - 1.0) * cos_omega) + common,
            -2.0 * ((amplitude - 1.0) + ((amplitude + 1.0) * cos_omega)),
            (amplitude + 1.0) + ((amplitude - 1.0) * cos_omega) - common
          ]
        else
          [
            amplitude * ((amplitude + 1.0) + ((amplitude - 1.0) * cos_omega) + common),
            -2.0 * amplitude * ((amplitude - 1.0) + ((amplitude + 1.0) * cos_omega)),
            amplitude * ((amplitude + 1.0) + ((amplitude - 1.0) * cos_omega) - common),
            (amplitude + 1.0) - ((amplitude - 1.0) * cos_omega) + common,
            2.0 * ((amplitude - 1.0) - ((amplitude + 1.0) * cos_omega)),
            (amplitude + 1.0) - ((amplitude - 1.0) * cos_omega) - common
          ]
        end
      end

      def normalize(b0, b1, b2, a0, a1, a2)
        [b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0]
      end
    end
  end
end
