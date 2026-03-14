# frozen_string_literal: true

module Deftones
  module Effects
    class JCReverb < Reverb
      def initialize(decay: 0.6, pre_delay: 0.003, **options)
        super(decay: decay, pre_delay: pre_delay, **options)
      end
    end
  end
end
