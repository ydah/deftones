# frozen_string_literal: true

module Deftones
  module Component
    class Split < Core::AudioNode
      attr_reader :left, :right

      def initialize(context: Deftones.context)
        super(context: context)
        @left = OutputTap.new(parent: self, channel: 0, context: context)
        @right = OutputTap.new(parent: self, channel: 1, context: context)
      end

      def render_channel(_channel, num_frames, start_frame = 0, cache = {})
        render(num_frames, start_frame, cache)
      end

      class OutputTap < Core::AudioNode
        def initialize(parent:, channel:, context: Deftones.context)
          super(context: context)
          @parent = parent
          @channel = channel
        end

        def render(num_frames, start_frame = 0, cache = {})
          @parent.render_channel(@channel, num_frames, start_frame, cache)
        end
      end
    end
  end
end
