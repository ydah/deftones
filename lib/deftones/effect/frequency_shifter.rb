# frozen_string_literal: true

module Deftones
  module Effects
    class FrequencyShifter < Core::Effect
      DEFAULT_KERNEL_SIZE = 31

      attr_accessor :frequency

      def initialize(frequency: 30.0, context: Deftones.context, **options)
        super(context: context, **options)
        @frequency = frequency.to_f
        @phase = 0.0
        @kernel = self.class.send(:hilbert_kernel, DEFAULT_KERNEL_SIZE)
        @delay = (@kernel.length / 2.0).floor
        @history = Array.new(@kernel.length, 0.0)
      end

      private

      def process_effect(input_buffer, num_frames, _start_frame, _cache)
        Array.new(num_frames) do |index|
          sample = input_buffer[index]
          analytic = analytic_components(sample)
          shifted = shift_analytic_signal(*analytic)
          advance_phase
          shifted
        end
      end

      def analytic_components(sample)
        @history.unshift(sample)
        @history.pop
        delayed = @history[@delay] || 0.0
        quadrature = @kernel.each_with_index.sum(0.0) do |coefficient, index|
          coefficient * (@history[index] || 0.0)
        end
        [delayed, quadrature]
      end

      def shift_analytic_signal(in_phase, quadrature)
        radians = 2.0 * Math::PI * @phase
        cosine = Math.cos(radians)
        sine = Math.sin(radians)
        if @frequency.negative?
          (in_phase * cosine) + (quadrature * sine)
        else
          (in_phase * cosine) - (quadrature * sine)
        end
      end

      def advance_phase
        @phase = (@phase + (shift_frequency / context.sample_rate)) % 1.0
      end

      def shift_frequency
        @frequency.abs
      end

      def self.hilbert_kernel(size)
        raise ArgumentError, "kernel size must be odd" if size.even?

        center = size / 2
        Array.new(size) do |index|
          offset = index - center
          next 0.0 if offset.zero? || offset.even?

          coefficient = 2.0 / (Math::PI * offset)
          window = 0.54 - (0.46 * Math.cos((2.0 * Math::PI * index) / (size - 1)))
          coefficient * window
        end
      end
    end
  end
end
