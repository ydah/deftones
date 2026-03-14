# frozen_string_literal: true

module Deftones
  module Analysis
    class DCMeter < Core::AudioNode
      attr_reader :offset

      def initialize(context: Deftones.context)
        super(context: context)
        @offset = 0.0
      end

      def process(input_buffer, num_frames, _start_frame, _cache)
        segment = input_buffer.first(num_frames)
        @offset = segment.sum / [segment.length, 1].max
        input_buffer
      end
    end
  end
end
