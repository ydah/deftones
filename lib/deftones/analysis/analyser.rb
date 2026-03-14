# frozen_string_literal: true

module Deftones
  module Analysis
    class Analyser < Core::AudioNode
      attr_reader :size

      def initialize(size: 1024, context: Deftones.context)
        super(context: context)
        @size = size
        @recent_samples = Array.new(size, 0.0)
      end

      def waveform
        Waveform.new(@recent_samples.dup)
      end

      def fft
        FFT.magnitudes(@recent_samples)
      end

      def process(input_buffer, num_frames, _start_frame, _cache)
        @recent_samples.concat(input_buffer.first(num_frames))
        @recent_samples = @recent_samples.last(@size)
        input_buffer
      end
    end
  end
end
