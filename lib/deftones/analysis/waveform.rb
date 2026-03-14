# frozen_string_literal: true

module Deftones
  module Analysis
    class Waveform
      attr_reader :samples

      def initialize(samples)
        @samples = samples
      end

      def peak
        @samples.map(&:abs).max || 0.0
      end

      def rms
        return 0.0 if @samples.empty?

        Math.sqrt(@samples.sum { |sample| sample * sample } / @samples.length)
      end
    end
  end
end
