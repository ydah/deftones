# frozen_string_literal: true

module Deftones
  module Component
    class Convolver < Core::Effect
      attr_reader :buffer
      attr_accessor :normalize

      def initialize(source = nil, wet: 1.0, normalize: false, context: Deftones.context, &onload)
        super(wet: wet, context: context)
        @normalize = normalize
        @buffer = nil
        @kernel = [1.0]
        @histories = []
        load(source, &onload) if source
      end

      def buffer=(value)
        load(value)
      end

      def load(source)
        @buffer = coerce_buffer(source)
        @kernel = normalize_kernel(@buffer.mono)
        @histories = []
        yield self if block_given?
        self
      end

      private

      def process_effect(input_buffer, num_frames, _start_frame, _cache, channel_index: 0)
        return input_buffer if passthrough?

        history = ensure_history(channel_index).dup

        output = Array.new(num_frames) do |index|
          history << input_buffer[index]
          sample = convolve(history)
          history.shift while history.length > @kernel.length
          sample
        end

        @histories[channel_index] = history
        output
      end

      def passthrough?
        @buffer.nil? || (@kernel.length == 1 && @kernel.first == 1.0)
      end

      def convolve(history)
        @kernel.each_with_index.sum do |coefficient, offset|
          history_index = history.length - 1 - offset
          next 0.0 if history_index.negative?

          coefficient * history[history_index]
        end
      end

      def coerce_buffer(source)
        return source if source.is_a?(IO::Buffer)

        IO::Buffer.load(source)
      end

      def normalize_kernel(samples)
        kernel = samples.map(&:to_f)
        return [1.0] if kernel.empty?

        return kernel unless @normalize

        peak = kernel.map(&:abs).max || 0.0
        return kernel if peak.zero?

        kernel.map { |sample| sample / peak }
      end

      def ensure_history(channel_index)
        required = [channel_index.to_i, 0].max
        while @histories.length <= required
          @histories << Array.new([@kernel.length - 1, 0].max, 0.0)
        end
        @histories[required]
      end
    end
  end
end
