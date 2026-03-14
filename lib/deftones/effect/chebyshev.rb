# frozen_string_literal: true

module Deftones
  module Effects
    class Chebyshev < Core::Effect
      attr_accessor :order

      def initialize(order: 3, **options)
        super(**options)
        @order = [order.to_i, 1].max
      end

      private

      def process_effect(input_buffer, _num_frames, _start_frame, _cache)
        input_buffer.map { |sample| chebyshev(sample.clamp(-1.0, 1.0), @order) }
      end

      def chebyshev(value, order)
        return value if order == 1

        previous = value
        current = (2.0 * value * value) - 1.0
        return current if order == 2

        3.upto(order) do
          next_value = (2.0 * value * current) - previous
          previous = current
          current = next_value
        end
        current
      end
    end
  end
end
