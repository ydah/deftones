# frozen_string_literal: true

module Deftones
  module Component
    class MidSideCompressor < Core::AudioNode
      attr_reader :input, :merge, :mid, :output, :side, :split

      def initialize(mid: {}, side: {}, context: Deftones.context)
        super(context: context)
        @split = MidSideSplit.new(context: context)
        @merge = MidSideMerge.new(context: context)
        @input = @split
        @output = @merge
        @mid = build_compressor(mid, context)
        @side = build_compressor(side, context)
        @split.mid >> @mid >> @merge.mid
        @split.side >> @side >> @merge.side
      end

      def render(num_frames, start_frame = 0, cache = {})
        @output.render(num_frames, start_frame, cache)
      end

      def render_block(num_frames, start_frame = 0, cache = {})
        @output.send(:render_block, num_frames, start_frame, cache)
      end

      private

      def build_compressor(definition, context)
        return definition if definition.is_a?(Compressor)

        Compressor.new(
          threshold: definition.fetch(:threshold, -24.0),
          ratio: definition.fetch(:ratio, 3.0),
          attack: definition.fetch(:attack, 0.01),
          release: definition.fetch(:release, 0.1),
          context: context
        )
      end
    end
  end
end
