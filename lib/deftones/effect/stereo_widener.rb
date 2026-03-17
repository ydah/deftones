# frozen_string_literal: true

module Deftones
  module Effects
    class StereoWidener < Core::Effect
      attr_accessor :width

      def initialize(width: 0.5, context: Deftones.context, **options)
        super(context: context, **options)
        @width = width.to_f
      end

      private

      def process_effect_block(input_block, num_frames, _start_frame, _cache)
        stereo_input = input_block.fit_channels(2)
        width = @width.to_f.clamp(0.0, 1.0)
        left = Array.new(num_frames)
        right = Array.new(num_frames)

        num_frames.times do |index|
          left_sample = stereo_input.channel_data[0][index]
          right_sample = stereo_input.channel_data[1][index]
          mid = (left_sample + right_sample) * 0.5
          side = (left_sample - right_sample) * 0.5 * width
          left[index] = mid + side
          right[index] = mid - side
        end

        Core::AudioBlock.from_channel_data([left, right])
      end
    end
  end
end
