# frozen_string_literal: true

module Deftones
  module Effects
    class Distortion < Core::Effect
      include Oversampling

      attr_accessor :amount

      def initialize(amount: 0.5, oversample: 1, **options)
        super(**options)
        @amount = amount.to_f
        self.oversample = oversample
      end

      private

      def process_effect(input_buffer, _num_frames, _start_frame, _cache, channel_index: 0)
        drive = 1.0 + (@amount * 20.0)
        process_oversampled(input_buffer, channel_index) { |sample| DSP::Helpers.soft_clip(sample, drive) }
      end
    end
  end
end
