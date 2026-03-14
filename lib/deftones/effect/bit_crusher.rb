# frozen_string_literal: true

module Deftones
  module Effects
    class BitCrusher < Core::Effect
      attr_accessor :bits, :downsample

      def initialize(bits: 8, downsample: 2, **options)
        super(**options)
        @bits = bits.to_i
        @downsample = [downsample.to_i, 1].max
        @hold_counter = 0
        @held_sample = 0.0
      end

      private

      def process_effect(input_buffer, _num_frames, _start_frame, _cache)
        step = 2.0 / (2**@bits)

        input_buffer.map do |sample|
          if (@hold_counter % @downsample).zero?
            @held_sample = ((sample / step).round * step).clamp(-1.0, 1.0)
          end
          @hold_counter += 1
          @held_sample
        end
      end
    end
  end
end
