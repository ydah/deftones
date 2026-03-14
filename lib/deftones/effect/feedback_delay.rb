# frozen_string_literal: true

module Deftones
  module Effects
    class FeedbackDelay < Core::Effect
      attr_reader :delay_time, :feedback

      def initialize(delay_time: "8n", feedback: 0.3, max_delay: 2.0, context: Deftones.context, **options)
        super(context: context, **options)
        @delay_time = Core::Signal.new(value: delay_time, units: :time, context: context)
        @feedback = Core::Signal.new(value: feedback, units: :number, context: context)
        @delay_line = DSP::DelayLine.new((max_delay * context.sample_rate).ceil)
      end

      private

      def process_effect(input_buffer, num_frames, start_frame, _cache)
        delays = @delay_time.process(num_frames, start_frame)
        feedbacks = @feedback.process(num_frames, start_frame)

        Array.new(num_frames) do |index|
          delay_samples = delays[index] * context.sample_rate
          @delay_line.tap(delay_samples, input_sample: input_buffer[index], feedback: feedbacks[index])
        end
      end
    end
  end
end
