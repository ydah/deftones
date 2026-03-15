# frozen_string_literal: true

module Deftones
  module Component
    class Follower < Core::AudioNode
      attr_reader :smoothing

      def initialize(smoothing: 0.05, context: Deftones.context)
        super(context: context)
        @smoothing = Core::Signal.new(value: smoothing, units: :time, context: context)
        @state = 0.0
      end

      def smoothing=(value)
        @smoothing.value = value
      end

      def process(input_buffer, num_frames, start_frame, _cache)
        smoothing_values = @smoothing.process(num_frames, start_frame)

        Array.new(num_frames) do |index|
          coefficient = smoothing_coefficient(smoothing_values[index])
          magnitude = input_buffer[index].abs
          @state += (1.0 - coefficient) * (magnitude - @state)
          @state
        end
      end

      def reset!
        @state = 0.0
        self
      end

      private

      def smoothing_coefficient(duration)
        seconds = [duration.to_f, 1.0 / context.sample_rate].max
        Math.exp(-1.0 / (seconds * context.sample_rate))
      end
    end
  end
end
