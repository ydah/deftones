# frozen_string_literal: true

module Deftones
  module Core
    class Gain < AudioNode
      attr_reader :gain

      def initialize(gain: 1.0, context: Deftones.context)
        super(context: context)
        @gain = Signal.new(value: gain, units: :number, context: context)
      end

      def gain=(value)
        @gain.value = value
      end

      def process(input_buffer, num_frames, start_frame, _cache)
        gain_values = @gain.process(num_frames, start_frame)

        Array.new(num_frames) do |index|
          input_buffer[index] * gain_values[index]
        end
      end

      def multichannel_process?
        true
      end

      def process(input_block, num_frames, start_frame, _cache)
        gain_values = @gain.process(num_frames, start_frame)
        AudioBlock.from_channel_data(
          input_block.channel_data.map do |channel|
            Array.new(num_frames) { |index| channel[index] * gain_values[index] }
          end
        )
      end
    end
  end
end
