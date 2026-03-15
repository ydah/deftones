# frozen_string_literal: true

module Deftones
  module Component
    class MultibandCompressor < Core::AudioNode
      attr_reader :high, :high_frequency, :input, :low, :low_frequency, :mid, :output, :q, :split

      def initialize(low_frequency: 400.0, high_frequency: 2_500.0, q: 1.0, low: {}, mid: {}, high: {},
                     context: Deftones.context)
        super(context: context)
        @split = MultibandSplit.new(
          low_frequency: low_frequency,
          high_frequency: high_frequency,
          q: q,
          context: context
        )
        @input = @split.input
        @output = self
        @low = Compressor.new(context: context, **compressor_options(low))
        @mid = Compressor.new(context: context, **compressor_options(mid))
        @high = Compressor.new(context: context, **compressor_options(high))
        @split.low >> @low
        @split.mid >> @mid
        @split.high >> @high
      end

      def low_frequency
        @split.low_frequency
      end

      def high_frequency
        @split.high_frequency
      end

      def q
        @split.q
      end

      def render(num_frames, start_frame = 0, cache = {})
        cache_key = [object_id, start_frame, num_frames]
        return cache.fetch(cache_key).dup if cache.key?(cache_key)

        low_buffer = @low.render(num_frames, start_frame, cache)
        mid_buffer = @mid.render(num_frames, start_frame, cache)
        high_buffer = @high.render(num_frames, start_frame, cache)

        output_buffer = Array.new(num_frames) do |index|
          low_buffer[index] + mid_buffer[index] + high_buffer[index]
        end

        cache[cache_key] = output_buffer
        output_buffer.dup
      end

      private

      def compressor_options(options)
        {
          threshold: options.fetch(:threshold, -24.0),
          ratio: options.fetch(:ratio, 3.0),
          attack: options.fetch(:attack, 0.01),
          release: options.fetch(:release, 0.1)
        }
      end
    end
  end
end
