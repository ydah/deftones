# frozen_string_literal: true

module Deftones
  module Effects
    class Tremolo < Core::Effect
      attr_accessor :frequency, :depth

      def initialize(frequency: 5.0, depth: 0.8, context: Deftones.context, **options)
        super(context: context, wet: 1.0, **options)
        @frequency = frequency.to_f
        @depth = depth.to_f
        @phase = 0.0
      end

      private

      def process_effect(input_buffer, num_frames, _start_frame, _cache)
        Array.new(num_frames) do |index|
          modulation = ((Math.sin(2.0 * Math::PI * @phase) + 1.0) * 0.5)
          @phase = (@phase + (@frequency / context.sample_rate)) % 1.0
          input_buffer[index] * (1.0 - (@depth * (1.0 - modulation)))
        end
      end
    end
  end
end
