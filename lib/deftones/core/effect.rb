# frozen_string_literal: true

module Deftones
  module Core
    class Effect < AudioNode
      attr_reader :wet

      def initialize(wet: 1.0, context: Deftones.context)
        super(context: context)
        @wet = Signal.new(value: wet, units: :number, context: context)
      end

      def wet=(value)
        @wet.value = value
      end

      def process(input_buffer, num_frames, start_frame, cache)
        wet_values = @wet.process(num_frames, start_frame)
        wet_buffer = process_effect(input_buffer.dup, num_frames, start_frame, cache)

        Array.new(num_frames) do |index|
          DSP::Helpers.mix(input_buffer[index], wet_buffer[index], wet_values[index].clamp(0.0, 1.0))
        end
      end

      private

      def process_effect(input_buffer, _num_frames, _start_frame, _cache)
        input_buffer
      end
    end
  end
end
