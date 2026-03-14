# frozen_string_literal: true

module Deftones
  module Analysis
    class Meter < Core::AudioNode
      attr_reader :peak, :rms

      def initialize(context: Deftones.context)
        super(context: context)
        @peak = 0.0
        @rms = 0.0
      end

      def process(input_buffer, num_frames, _start_frame, _cache)
        segment = input_buffer.first(num_frames)
        @peak = segment.map(&:abs).max || 0.0
        @rms = Math.sqrt(segment.sum { |sample| sample * sample } / [segment.length, 1].max)
        input_buffer
      end
    end
  end
end
