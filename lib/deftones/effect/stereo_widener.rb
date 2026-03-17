# frozen_string_literal: true

module Deftones
  module Effects
    class StereoWidener < Core::Effect
      attr_accessor :width

      def initialize(width: 0.5, context: Deftones.context, **options)
        super(context: context, **options)
        @width = width.to_f
      end

      private

      def process_effect(input_buffer, num_frames, _start_frame, _cache)
        input_buffer.dup
      end
    end
  end
end
