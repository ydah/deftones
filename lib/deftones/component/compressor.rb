# frozen_string_literal: true

module Deftones
  module Component
    class Compressor < Core::AudioNode
      attr_accessor :threshold, :ratio, :attack, :release

      def initialize(threshold: -18.0, ratio: 4.0, attack: 0.01, release: 0.1, context: Deftones.context)
        super(context: context)
        @threshold = threshold.to_f
        @ratio = ratio.to_f
        @attack = attack.to_f
        @release = release.to_f
        @gain_db = 0.0
      end

      def process(input_buffer, num_frames, _start_frame, _cache)
        Array.new(num_frames) do |index|
          compress(input_buffer[index])
        end
      end

      private

      def compress(sample)
        level = [sample.abs, 1.0e-9].max
        level_db = 20.0 * Math.log10(level)
        target_gain_db =
          if level_db > @threshold
            compressed_db = @threshold + ((level_db - @threshold) / [@ratio, 1.0].max)
            compressed_db - level_db
          else
            0.0
          end

        smoothing = target_gain_db < @gain_db ? attack_smoothing : release_smoothing
        @gain_db += (target_gain_db - @gain_db) * smoothing
        sample * (10.0**(@gain_db / 20.0))
      end

      def attack_smoothing
        1.0 / [(@attack * context.sample_rate), 1.0].max
      end

      def release_smoothing
        1.0 / [(@release * context.sample_rate), 1.0].max
      end
    end
  end
end
