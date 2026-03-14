# frozen_string_literal: true

module Deftones
  module Component
    class CrossFade < Core::AudioNode
      attr_reader :input, :output, :a, :b, :fade

      def initialize(fade: 0.5, context: Deftones.context)
        super(context: context)
        @a = Core::Gain.new(context: context)
        @b = Core::Gain.new(context: context)
        @fade = Core::Signal.new(value: fade, units: :number, context: context)
        @input = @a
        @output = self
      end

      def fade=(value)
        @fade.value = value
      end

      def left
        @a
      end

      def right
        @b
      end

      def render(num_frames, start_frame = 0, cache = {})
        cache_key = [object_id, start_frame, num_frames]
        return cache.fetch(cache_key).dup if cache.key?(cache_key)

        fades = @fade.process(num_frames, start_frame)
        a_buffer = @a.render(num_frames, start_frame, cache)
        b_buffer = @b.render(num_frames, start_frame, cache)
        output_buffer = Array.new(num_frames) do |index|
          DSP::Helpers.mix(a_buffer[index], b_buffer[index], fades[index].clamp(0.0, 1.0))
        end

        cache[cache_key] = output_buffer
        output_buffer.dup
      end
    end
  end
end
