# frozen_string_literal: true

module Deftones
  module Component
    class Gate < Core::AudioNode
      attr_accessor :threshold, :release

      def initialize(threshold: -40.0, release: 0.05, context: Deftones.context)
        super(context: context)
        @threshold = threshold.to_f
        @release = release.to_f
        @gain = 0.0
      end

      def process(input_buffer, num_frames, _start_frame, _cache)
        Array.new(num_frames) do |index|
          gate(input_buffer[index])
        end
      end

      private

      def gate(sample)
        level_db = 20.0 * Math.log10([sample.abs, 1.0e-9].max)
        target = level_db >= @threshold ? 1.0 : 0.0
        smoothing = 1.0 / [(@release * context.sample_rate), 1.0].max
        @gain += (target - @gain) * smoothing
        sample * @gain
      end
    end
  end
end
