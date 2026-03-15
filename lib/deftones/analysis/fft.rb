# frozen_string_literal: true

module Deftones
  module Analysis
    class FFT < Core::AudioNode
      def self.magnitudes(samples)
        size = samples.length
        half = size / 2

        Array.new(half) do |bin|
          real = 0.0
          imaginary = 0.0

          samples.each_with_index do |sample, index|
            angle = (2.0 * Math::PI * bin * index) / size
            real += sample * Math.cos(angle)
            imaginary -= sample * Math.sin(angle)
          end

          Math.sqrt((real * real) + (imaginary * imaginary)) / [size, 1].max
        end
      end

      def self.decibels(samples, floor: -100.0)
        magnitudes(samples).map do |magnitude|
          [Deftones.gain_to_db([magnitude, 1.0e-12].max), floor.to_f].max
        end
      end

      def initialize(size: 1024, smoothing: 0.8, return_type: :float, normal_range: false,
                     min_decibels: -100.0, max_decibels: 0.0, context: Deftones.context)
        super(context: context)
        @delegate = Analysis::Analyser.new(
          size: size,
          type: :fft,
          smoothing: smoothing,
          return_type: return_type,
          normal_range: normal_range,
          min_decibels: min_decibels,
          max_decibels: max_decibels,
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

      def min_decibels
        @delegate.min_decibels
      end

      def min_decibels=(value)
        @delegate.min_decibels = value
      end

      def max_decibels
        @delegate.max_decibels
      end

      def max_decibels=(value)
        @delegate.max_decibels = value
      end

      def get_value
        @delegate.get_value
      end

      alias getValue get_value
      alias returnType return_type
      alias normalRange normal_range
      alias minDecibels min_decibels
      alias maxDecibels max_decibels

      def returnType=(value)
        self.return_type = value
      end

      def normalRange=(value)
        self.normal_range = value
      end

      def minDecibels=(value)
        self.min_decibels = value
      end

      def maxDecibels=(value)
        self.max_decibels = value
      end

      def process(input_buffer, num_frames, start_frame, cache)
        @delegate.process(input_buffer, num_frames, start_frame, cache)
      end
    end
  end
end
