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

      def process(input_buffer, num_frames, start_frame, _cache)
        gains = @volume.process(num_frames, start_frame)
        Array.new(num_frames) { |index| input_buffer[index] * gains[index] }
      end
    end
  end
end
