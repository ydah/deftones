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
        @kernels = [[1.0]]
        @histories = []
        load(source, &onload) if source
      end

      def buffer=(value)
        load(value)
      end

      def load(source)
        @buffer = coerce_buffer(source)
        @kernels = normalize_kernels(@buffer.to_array)
        @histories = []
        yield self if block_given?
        self
      end

      private

      def process_effect_block(input_block, num_frames, _start_frame, _cache)
        return input_block if passthrough?

        output_channels = [input_block.channels, @kernels.length].max
        source = input_block.fit_channels([input_block.channels, 1].max)
        output = Array.new(output_channels) { Array.new(num_frames, 0.0) }

        output_channels.times do |channel_index|
          kernel = @kernels[channel_index % @kernels.length]
          history = ensure_history(channel_index, kernel.length).dup
          input_channel = source.channel_data[[channel_index, source.channels - 1].min]

          output[channel_index] = Array.new(num_frames) do |frame_index|
            history << input_channel[frame_index]
            sample = convolve(history, kernel)
            history.shift while history.length > kernel.length
            sample
          end

          @histories[channel_index] = history
        end

        Core::AudioBlock.from_channel_data(output)
      end

      def passthrough?
        @buffer.nil? || (@kernels.length == 1 && @kernels.first.length == 1 && @kernels.first.first == 1.0)
      end

      def convolve(history, kernel)
        kernel.each_with_index.sum do |coefficient, offset|
          history_index = history.length - 1 - offset
          next 0.0 if history_index.negative?

          coefficient * history[history_index]
        end
      end

      def coerce_buffer(source)
        return source if source.is_a?(IO::Buffer)

        IO::Buffer.load(source)
      end

      def normalize_kernels(channel_arrays)
        kernels = channel_arrays.map { |channel| channel.map(&:to_f) }.reject(&:empty?)
        return [[1.0]] if kernels.empty?
        return kernels unless @normalize

        peak = kernels.flatten.map(&:abs).max || 0.0
        return kernels if peak.zero?

        kernels.map { |kernel| kernel.map { |sample| sample / peak } }
      end

      def ensure_history(channel_index, kernel_length)
        required = [channel_index.to_i, 0].max
        while @histories.length <= required
          @histories << Array.new([kernel_length - 1, 0].max, 0.0)
        end
        if @histories[required].length != [kernel_length - 1, 0].max
          @histories[required] = Array.new([kernel_length - 1, 0].max, 0.0)
        end
        @histories[required]
      end
    end
  end
end
