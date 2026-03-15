# frozen_string_literal: true

module Deftones
  module Analysis
    class Waveform < Core::AudioNode
      class Snapshot
        attr_reader :samples

        def initialize(samples)
          @samples = samples
        end

        def peak
          @samples.map(&:abs).max || 0.0
        end

        def rms
          return 0.0 if @samples.empty?

          Math.sqrt(@samples.sum { |sample| sample * sample } / @samples.length)
        end
      end

      def initialize(size: 1024, smoothing: 0.8, return_type: :float, normal_range: false, context: Deftones.context)
        super(context: context)
        @delegate = Analysis::Analyser.new(
          size: size,
          type: :waveform,
          smoothing: smoothing,
          return_type: return_type,
          normal_range: normal_range,
          context: context
        )
      end

      def size
        @delegate.size
      end

      def size=(value)
        @delegate.size = value
      end

      def smoothing
        @delegate.smoothing
      end

      def smoothing=(value)
        @delegate.smoothing = value
      end

      def return_type
        @delegate.return_type
      end

      def return_type=(value)
        @delegate.return_type = value
      end

      def normal_range
        @delegate.normal_range
      end

      def normal_range=(value)
        @delegate.normal_range = value
      end

      def get_value
        @delegate.get_value
      end

      alias getValue get_value
      alias returnType return_type
      alias normalRange normal_range

      def returnType=(value)
        self.return_type = value
      end

      def normalRange=(value)
        self.normal_range = value
      end

      def process(input_buffer, num_frames, start_frame, cache)
        @delegate.process(input_buffer, num_frames, start_frame, cache)
      end
    end
  end
end
