# frozen_string_literal: true

module Deftones
  module Effects
    class PingPongDelay < FeedbackDelay
      def initialize(max_delay: 2.0, **options)
        super(max_delay: max_delay, **options)
        @left_delay_line = DSP::DelayLine.new(@max_delay_samples)
        @right_delay_line = DSP::DelayLine.new(@max_delay_samples)
      end

      private

      def process_effect_block(input_block, num_frames, start_frame, _cache)
        delays = @delay_time.process(num_frames, start_frame)
        feedbacks = @feedback.process(num_frames, start_frame)
        source = input_block.fit_channels(2)
        left = Array.new(num_frames, 0.0)
        right = Array.new(num_frames, 0.0)

        num_frames.times do |index|
          delay_samples = delays[index] * context.sample_rate
          feedback = feedbacks[index].to_f.clamp(-0.999, 0.999)
          left_tap = @left_delay_line.read(delay_samples)
          right_tap = @right_delay_line.read(delay_samples)
          input_left = input_block.channels == 1 ? input_block.mono[index] : source.channel_data[0][index]
          input_right = input_block.channels == 1 ? 0.0 : source.channel_data[1][index]

          @left_delay_line.write(input_left + (right_tap * feedback))
          @right_delay_line.write(input_right + (left_tap * feedback))

          left[index] = left_tap
          right[index] = right_tap
        end

        Core::AudioBlock.from_channel_data([left, right])
      end
    end
  end
end
