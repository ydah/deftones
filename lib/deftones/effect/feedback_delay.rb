# frozen_string_literal: true

module Deftones
  module Effects
    class FeedbackDelay < Core::Effect
      attr_reader :delay_time, :feedback

      def initialize(delay_time: "8n", feedback: 0.3, max_delay: 2.0, context: Deftones.context, **options)
        super(context: context, **options)
        @delay_time = Core::Signal.new(value: delay_time, units: :time, context: context)
        @feedback = Core::Signal.new(value: feedback, units: :number, context: context)
        @max_delay_samples = (max_delay * context.sample_rate).ceil
        @delay_lines = []
      end

      private

      def process_effect(input_buffer, num_frames, start_frame, _cache, channel_index: 0)
        delays = @delay_time.process(num_frames, start_frame)
        feedbacks = @feedback.process(num_frames, start_frame)
        delay_line = ensure_delay_line(channel_index)

        Array.new(num_frames) do |index|
          delay_samples = delays[index] * context.sample_rate
          delay_line.tap(delay_samples, input_sample: input_buffer[index], feedback: feedbacks[index])
        end
      end

      def ensure_delay_line(channel_index)
        required = [channel_index.to_i, 0].max
        while @delay_lines.length <= required
          @delay_lines << DSP::DelayLine.new(@max_delay_samples)
        end
        @delay_lines[required]
      end
    end
  end
end
