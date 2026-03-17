# frozen_string_literal: true

module Deftones
  module Effects
    class PingPongDelay < FeedbackDelay
      def initialize(max_delay: 2.0, **options)
        super(max_delay: max_delay, **options)
        @primary_delay_line = @delay_line
        @secondary_delay_line = DSP::DelayLine.new((max_delay * context.sample_rate).ceil)
      end

      private

      def process_effect(input_buffer, num_frames, start_frame, _cache)
        delays = @delay_time.process(num_frames, start_frame)
        feedbacks = @feedback.process(num_frames, start_frame)

        Array.new(num_frames) do |index|
          delay_samples = delays[index] * context.sample_rate
          primary = @primary_delay_line.read(delay_samples)
          secondary = @secondary_delay_line.read(delay_samples)

          @primary_delay_line.write(input_buffer[index] + (secondary * feedbacks[index]))
          @secondary_delay_line.write(primary * feedbacks[index])

          primary + secondary
        end
      end
    end
  end
end
