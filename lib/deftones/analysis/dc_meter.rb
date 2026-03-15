# frozen_string_literal: true

module Deftones
  module Analysis
    class DCMeter < Core::AudioNode
      attr_reader :offset

      def initialize(smoothing: 0.8, context: Deftones.context)
        super(context: context)
        @offset = 0.0
        self.smoothing = smoothing
      end

      def smoothing
        @smoothing
      end

      def smoothing=(value)
        @smoothing = Deftones::DSP::Helpers.clamp(value.to_f, 0.0, 1.0)
      end

      def get_value
        @offset
      end

      def process(input_buffer, num_frames, _start_frame, _cache)
        segment = input_buffer.first(num_frames)
        instantaneous_offset = segment.sum / [segment.length, 1].max
        @offset = smooth(@offset, instantaneous_offset)
        input_buffer
      end

      alias getValue get_value

      private

      def smooth(previous, current)
        return current if @smoothing.zero?

        (previous.to_f * @smoothing) + (current.to_f * (1.0 - @smoothing))
      end
    end
  end
end
