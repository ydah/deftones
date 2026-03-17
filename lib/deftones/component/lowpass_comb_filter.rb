# frozen_string_literal: true

module Deftones
  module Component
    class LowpassCombFilter < FeedbackCombFilter
      attr_reader :dampening

      def initialize(dampening: 3_000.0, **options)
        super(**options)
        @dampening = Core::Signal.new(value: dampening, units: :frequency, context: context)
        @filter_state = []
      end

      def dampening=(value)
        @dampening.value = value
      end

      def reset!
        @filter_state = []
        super
      end

      private

      def filtered_feedback(sample, index, start_frame, channel_index = 0)
        ensure_filter_state(channel_index + 1)
        coefficient = feedback_coefficient(@dampening.process(1, start_frame + index).first)
        @filter_state[channel_index] += (1.0 - coefficient) * (sample - @filter_state[channel_index])
        @filter_state[channel_index]
      end

      def feedback_coefficient(frequency)
        normalized = [[frequency.to_f, 1.0].max, (context.sample_rate * 0.49)].min
        Math.exp((-2.0 * Math::PI * normalized) / context.sample_rate)
      end

      def ensure_filter_state(channels)
        required = [channels.to_i, 1].max
        @filter_state.fill(0.0, @filter_state.length...required)
      end
    end
  end
end
