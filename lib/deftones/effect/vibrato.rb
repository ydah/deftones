# frozen_string_literal: true

module Deftones
  module Effects
    class Vibrato < Core::Effect
      attr_accessor :frequency, :depth

      def initialize(frequency: 5.0, depth: 0.002, context: Deftones.context, **options)
        super(context: context, wet: 1.0, **options)
        @frequency = frequency.to_f
        @depth = depth.to_f
        @phase = 0.0
        @delay_line = DSP::DelayLine.new((0.05 * context.sample_rate).ceil)
      end

      private

      def process_effect(input_buffer, num_frames, _start_frame, _cache)
        Array.new(num_frames) do |index|
          delay_samples = (0.01 + (@depth * ((Math.sin(2.0 * Math::PI * @phase) + 1.0) * 0.5))) * context.sample_rate
          @phase = (@phase + (@frequency / context.sample_rate)) % 1.0
          @delay_line.tap(delay_samples, input_sample: input_buffer[index])
        end
      end
    end
  end
end
