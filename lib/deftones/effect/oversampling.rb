# frozen_string_literal: true

module Deftones
  module Effects
    module Oversampling
      OVERSAMPLE_FACTORS = [1, 2, 4].freeze

      attr_reader :oversample

      def oversample=(value)
        normalized = value.to_i
        raise ArgumentError, "Unsupported oversample factor: #{value}" unless OVERSAMPLE_FACTORS.include?(normalized)

        @oversample = normalized
        @oversample_previous = []
      end

      private

      def process_oversampled(input_buffer, channel_index)
        ensure_oversample_state(channel_index)
        return input_buffer.map { |sample| yield sample } if @oversample == 1

        input_buffer.map do |sample|
          previous = @oversample_previous[channel_index]
          current = sample.to_f
          sum = 0.0
          1.upto(@oversample) do |step|
            position = step.to_f / @oversample
            sum += yield Deftones::DSP::Helpers.lerp(previous, current, position)
          end
          @oversample_previous[channel_index] = current
          sum / @oversample
        end
      end

      def ensure_oversample_state(channel_index)
        required = [channel_index.to_i, 0].max
        @oversample_previous.fill(0.0, @oversample_previous.length..required)
      end
    end
  end
end
