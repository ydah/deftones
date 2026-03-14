# frozen_string_literal: true

module Deftones
  module Effects
    class Distortion < Core::Effect
      attr_accessor :amount

      def initialize(amount: 0.5, **options)
        super(**options)
        @amount = amount.to_f
      end

      private

      def process_effect(input_buffer, _num_frames, _start_frame, _cache)
        drive = 1.0 + (@amount * 20.0)
        input_buffer.map { |sample| DSP::Helpers.soft_clip(sample, drive) }
      end
    end
  end
end
