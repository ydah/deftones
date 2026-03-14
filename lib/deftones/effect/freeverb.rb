# frozen_string_literal: true

module Deftones
  module Effects
    class Freeverb < Reverb
      def initialize(decay: 0.82, pre_delay: 0.005, **options)
        super(decay: decay, pre_delay: pre_delay, **options)
      end
    end
  end
end
