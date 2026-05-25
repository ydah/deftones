# frozen_string_literal: true

module Deftones
  module Component
    class Compressor < Core::AudioNode
      attr_reader :threshold, :ratio, :attack, :release

      def initialize(threshold: -18.0, ratio: 4.0, attack: 0.01, release: 0.1, context: Deftones.context)
        super(context: context)
        @gain_db = []
        self.threshold = threshold
        self.ratio = ratio
        self.attack = attack
        self.release = release
      end

      def threshold=(value)
        @threshold = value.to_f
      end

      def ratio=(value)
        @ratio = value.to_f
      end

      def attack=(value)
        @attack = value.to_f
        @attack_smoothing = smoothing_for(@attack)
      end

      def release=(value)
        @release = value.to_f
        @release_smoothing = smoothing_for(@release)
      end

      def multichannel_process?
        true
      end

      def process(input_block, num_frames, _start_frame, _cache)
        ensure_gain_state(input_block.channels)
        Core::AudioBlock.from_channel_data(
          input_block.channel_data.each_with_index.map do |channel, channel_index|
            Array.new(num_frames) { |index| compress(channel[index], channel_index) }
          end
        )
      end

      private

      def compress(sample, channel_index)
        level = [sample.abs, 1.0e-9].max
        level_db = 20.0 * Math.log10(level)
        target_gain_db =
          if level_db > @threshold
            compressed_db = @threshold + ((level_db - @threshold) / [@ratio, 1.0].max)
            compressed_db - level_db
          else
            0.0
          end

        current_gain_db = @gain_db[channel_index]
        smoothing = target_gain_db < current_gain_db ? @attack_smoothing : @release_smoothing
        current_gain_db += (target_gain_db - current_gain_db) * smoothing
        @gain_db[channel_index] = current_gain_db
        sample * (10.0**(current_gain_db / 20.0))
      end

      def smoothing_for(seconds)
        1.0 / [(seconds.to_f * context.sample_rate), 1.0].max
      end

      def ensure_gain_state(channels)
        required = [channels.to_i, 1].max
        @gain_db.fill(0.0, @gain_db.length...required)
      end
    end
  end
end
