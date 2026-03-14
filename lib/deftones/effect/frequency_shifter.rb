# frozen_string_literal: true

module Deftones
  module Effects
    class FrequencyShifter < Core::Effect
      attr_accessor :frequency

      def initialize(frequency: 30.0, context: Deftones.context, **options)
        super(context: context, **options)
        @frequency = frequency.to_f
        @phase = 0.0
      end

      private

      def process_effect(input_buffer, num_frames, _start_frame, _cache)
        Array.new(num_frames) do |index|
          modulator = Math.sin(2.0 * Math::PI * @phase)
          @phase = (@phase + (@frequency / context.sample_rate)) % 1.0
          input_buffer[index] * modulator
        end
      end
    end
  end
end
