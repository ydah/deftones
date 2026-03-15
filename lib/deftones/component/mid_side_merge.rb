# frozen_string_literal: true

module Deftones
  module Component
    class MidSideMerge < Core::AudioNode
      SQRT_ONE_HALF = Math.sqrt(0.5)

      attr_reader :input, :output, :mid, :side

      def initialize(context: Deftones.context)
        super(context: context)
        @mid = Core::Gain.new(context: context)
        @side = Core::Gain.new(context: context)
        @input = @mid
        @output = self
      end

      def render(num_frames, start_frame = 0, cache = {})
        cache_key = [object_id, start_frame, num_frames]
        return cache.fetch(cache_key).dup if cache.key?(cache_key)

        mid_buffer = @mid.render(num_frames, start_frame, cache)
        side_buffer = @side.render(num_frames, start_frame, cache)

        output_buffer = Array.new(num_frames) do |index|
          left = (mid_buffer[index] + side_buffer[index]) * SQRT_ONE_HALF
          right = (mid_buffer[index] - side_buffer[index]) * SQRT_ONE_HALF
          (left + right) * 0.5
        end

        cache[cache_key] = output_buffer
        output_buffer.dup
      end
    end
  end
end
