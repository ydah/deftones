# frozen_string_literal: true

module Deftones
  module Component
    class Limiter < Compressor
      def initialize(threshold: -1.0, ratio: 20.0, attack: 0.001, release: 0.05, **options)
        super(threshold: threshold, ratio: ratio, attack: attack, release: release, **options)
      end
    end
  end
end
