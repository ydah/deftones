# frozen_string_literal: true

module Deftones
  module Analysis
    class FFT
      def self.magnitudes(samples)
        size = samples.length
        half = size / 2

        Array.new(half) do |bin|
          real = 0.0
          imaginary = 0.0

          samples.each_with_index do |sample, index|
            angle = (2.0 * Math::PI * bin * index) / size
            real += sample * Math.cos(angle)
            imaginary -= sample * Math.sin(angle)
          end

          Math.sqrt((real * real) + (imaginary * imaginary)) / [size, 1].max
        end
      end
    end
  end
end
