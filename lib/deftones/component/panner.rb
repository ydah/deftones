# frozen_string_literal: true

module Deftones
  module Component
    class Panner < Core::AudioNode
      attr_reader :pan

      def initialize(pan: 0.0, context: Deftones.context)
        super(context: context)
        @pan = Core::Signal.new(value: pan, units: :number, context: context)
      end

      def pan=(value)
        @pan.value = value
      end

      def process(input_buffer, num_frames, start_frame, _cache)
        pans = @pan.process(num_frames, start_frame)
        Array.new(num_frames) do |index|
          input_buffer[index] * (1.0 - (pans[index].abs * 0.2))
        end
      end
    end
  end
end
