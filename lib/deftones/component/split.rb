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

      def render_channel_block(channel, num_frames, start_frame = 0, cache = {})
        input_block = send(:mix_source_blocks, num_frames, start_frame, cache)
        output_channel = if input_block.channels == 1
                           input_block.channel(0)
                         elsif channel < input_block.channels
                           input_block.channel(channel)
                         else
                           Array.new(num_frames, 0.0)
                         end
        Core::AudioBlock.from_channel_data([output_channel])
      end

      class OutputTap < Core::AudioNode
        def initialize(parent:, channel:, context: Deftones.context)
          super(context: context)
          @parent = parent
          @channel = channel
        end

        def render_block(num_frames, start_frame = 0, cache = {})
          @parent.render_channel_block(@channel, num_frames, start_frame, cache)
        end

        def render(num_frames, start_frame = 0, cache = {})
          @parent.render_channel(@channel, num_frames, start_frame, cache)
        end
      end
    end
  end
end
