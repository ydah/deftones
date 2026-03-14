# frozen_string_literal: true

module Deftones
  module Effects
    class Chorus < Core::Effect
      attr_accessor :frequency, :depth, :delay_time

      def initialize(frequency: 1.5, depth: 0.003, delay_time: 0.015, context: Deftones.context, **options)
        super(context: context, **options)
        @frequency = frequency.to_f
        @depth = depth.to_f
        @delay_time = delay_time.to_f
        @phase = 0.0
        @delay_line = DSP::DelayLine.new((0.1 * context.sample_rate).ceil)
      end

      private

      def process_effect(input_buffer, num_frames, _start_frame, _cache)
        Array.new(num_frames) do |index|
          modulation = (Math.sin(2.0 * Math::PI * @phase) + 1.0) * 0.5
          delay_samples = (@delay_time + (@depth * modulation)) * context.sample_rate
          @phase = (@phase + (@frequency / context.sample_rate)) % 1.0
          @delay_line.tap(delay_samples, input_sample: input_buffer[index])
        end
      end
    end
  end
end
