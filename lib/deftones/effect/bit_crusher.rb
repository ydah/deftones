# frozen_string_literal: true

module Deftones
  module Effects
    class BitCrusher < Core::Effect
      include Oversampling

      attr_accessor :bits, :downsample

      def initialize(bits: 8, downsample: 2, oversample: 1, **options)
        super(**options)
        @bits = bits.to_i
        @downsample = [downsample.to_i, 1].max
        self.oversample = oversample
        @hold_counters = []
        @held_samples = []
      end

      private

      def process_effect(input_buffer, _num_frames, _start_frame, _cache, channel_index: 0)
        step = 2.0 / (2**@bits)
        ensure_state(channel_index)

        input_buffer.map do |sample|
          if (@hold_counters[channel_index] % @downsample).zero?
            @held_samples[channel_index] =
              process_oversampled([sample], channel_index) { |candidate| quantize(candidate, step) }.first
          end
          @hold_counters[channel_index] += 1
          @held_samples[channel_index]
        end
      end

      def quantize(sample, step)
        ((sample / step).round * step).clamp(-1.0, 1.0)
      end

      def ensure_state(channel_index)
        required = [channel_index.to_i, 0].max
        @hold_counters.fill(0, @hold_counters.length..required)
        @held_samples.fill(0.0, @held_samples.length..required)
      end
    end
  end
end
