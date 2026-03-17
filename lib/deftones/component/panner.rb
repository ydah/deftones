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
          input_buffer[index] * fold_down_gain(pans[index])
        end
      end

      private

      def fold_down_gain(pan)
        normalized = pan.to_f.clamp(-1.0, 1.0)
        angle = ((normalized + 1.0) * Math::PI) * 0.25
        (Math.cos(angle) + Math.sin(angle)) * 0.5
      end
    end
  end
end
