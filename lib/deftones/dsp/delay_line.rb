# frozen_string_literal: true

module Deftones
  module DSP
    class DelayLine
      def initialize(max_delay_samples)
        @buffer = Array.new([max_delay_samples.to_i + 2, 2].max, 0.0)
        @write_index = 0
      end

      def read(delay_samples)
        fractional_read(delay_samples.to_f)
      end

      def write(sample)
        @buffer[@write_index] = sample
        @write_index = (@write_index + 1) % @buffer.length
        sample
      end

      def tap(delay_samples, input_sample: 0.0, feedback: 0.0)
        delayed_sample = read(delay_samples)
        write(input_sample + (delayed_sample * feedback))
        delayed_sample
      end

      private

      def fractional_read(delay_samples)
        read_position = @write_index - delay_samples
        read_position += @buffer.length while read_position.negative?

        base_index = read_position.floor % @buffer.length
        next_index = (base_index + 1) % @buffer.length
        fraction = read_position - read_position.floor

        Helpers.lerp(@buffer[base_index], @buffer[next_index], fraction)
      end
    end
  end
end
