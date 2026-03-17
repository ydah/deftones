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

      def multichannel_process?
        true
      end

      def process(input_block, num_frames, start_frame, _cache)
        pans = @pan.process(num_frames, start_frame)
        mono_input = input_block.mono

        Core::AudioBlock.from_channel_data([
          Array.new(num_frames) { |index| mono_input[index] * left_gain(pans[index]) },
          Array.new(num_frames) { |index| mono_input[index] * right_gain(pans[index]) }
        ])
      end

      private

      def fold_down_gain(pan)
        normalized = pan.to_f.clamp(-1.0, 1.0)
        angle = ((normalized + 1.0) * Math::PI) * 0.25
        (Math.cos(angle) + Math.sin(angle)) * 0.5
      end

      def left_gain(pan)
        angle_for(pan).then { |angle| Math.cos(angle) }
      end

      def right_gain(pan)
        angle_for(pan).then { |angle| Math.sin(angle) }
      end

      def angle_for(pan)
        ((pan.to_f.clamp(-1.0, 1.0) + 1.0) * Math::PI) * 0.25
      end
    end
  end
end
