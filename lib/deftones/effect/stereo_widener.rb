# frozen_string_literal: true

module Deftones
  module Effects
    class StereoWidener < Core::Effect
      attr_accessor :width

      def initialize(width: 0.5, context: Deftones.context, **options)
        super(context: context, **options)
        @width = width.to_f
        @delay_line = DSP::DelayLine.new((0.03 * context.sample_rate).ceil)
      end

      private

      def process_effect(input_buffer, num_frames, _start_frame, _cache)
        Array.new(num_frames) do |index|
          delayed = @delay_line.tap(0.01 * context.sample_rate, input_sample: input_buffer[index])
          input_buffer[index] + (delayed * @width * 0.35)
        end
      end
    end
  end
end
