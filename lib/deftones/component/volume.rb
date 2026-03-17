# frozen_string_literal: true

module Deftones
  module Component
    class Volume < Core::AudioNode
      attr_reader :volume

      def initialize(volume: 0.0, context: Deftones.context)
        super(context: context)
        @volume = Core::Signal.new(value: volume, units: :decibels, context: context)
      end

      def volume=(value)
        @volume.value = value
      end

      def multichannel_process?
        true
      end

      def process(input_block, num_frames, start_frame, _cache)
        gains = @volume.process(num_frames, start_frame)
        Core::AudioBlock.from_channel_data(
          input_block.channel_data.map do |channel|
            Array.new(num_frames) { |index| channel[index] * gains[index] }
          end
        )
      end
    end
  end
end
