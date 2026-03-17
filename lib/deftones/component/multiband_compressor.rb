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
        render_block(num_frames, start_frame, cache).mono
      end

      def render_block(num_frames, start_frame = 0, cache = {})
        cache_key = [object_id, start_frame, num_frames]
        return cache.fetch(cache_key).dup if cache.key?(cache_key)

        low_buffer = @low.send(:render_block, num_frames, start_frame, cache)
        mid_buffer = @mid.send(:render_block, num_frames, start_frame, cache)
        high_buffer = @high.send(:render_block, num_frames, start_frame, cache)
        channels = [low_buffer.channels, mid_buffer.channels, high_buffer.channels].max
        output_buffer = Core::AudioBlock.silent(num_frames, channels)
        output_buffer.mix!(low_buffer).mix!(mid_buffer).mix!(high_buffer)

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
