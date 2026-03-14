# frozen_string_literal: true

module Deftones
  module Effects
    class PingPongDelay < FeedbackDelay
      def initialize(**options)
        super(**options)
        @phase = 1.0
      end

      private

      def process_effect(input_buffer, num_frames, start_frame, cache)
        super.map do |sample|
          @phase *= -1.0
          sample * @phase
        end
      end
    end
  end
end
