# frozen_string_literal: true

module Deftones
  module Component
    class Gate < Core::AudioNode
      attr_accessor :threshold, :release

      def initialize(threshold: -40.0, release: 0.05, context: Deftones.context)
        super(context: context)
        @threshold = threshold.to_f
        @release = release.to_f
        @gain = []
      end

      def multichannel_process?
        true
      end

      def process(input_block, num_frames, _start_frame, _cache)
        ensure_gain_state(input_block.channels)
        Core::AudioBlock.from_channel_data(
          input_block.channel_data.each_with_index.map do |channel, channel_index|
            Array.new(num_frames) { |index| gate(channel[index], channel_index) }
          end
        )
      end

      private

      def gate(sample, channel_index)
        level_db = 20.0 * Math.log10([sample.abs, 1.0e-9].max)
        target = level_db >= @threshold ? 1.0 : 0.0
        smoothing = 1.0 / [(@release * context.sample_rate), 1.0].max
        gain = @gain[channel_index]
        gain += (target - gain) * smoothing
        @gain[channel_index] = gain
        sample * gain
      end

      def ensure_gain_state(channels)
        required = [channels.to_i, 1].max
        @gain.fill(0.0, @gain.length...required)
      end
    end
  end
end
