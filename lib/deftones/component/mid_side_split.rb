# frozen_string_literal: true

module Deftones
  module Component
    class MidSideSplit < Core::AudioNode
      SQRT_TWO = Math.sqrt(2.0)

      attr_reader :mid, :side

      def initialize(context: Deftones.context)
        super(context: context)
        @mid = OutputTap.new(parent: self, mode: :mid, context: context)
        @side = OutputTap.new(parent: self, mode: :side, context: context)
      end

      def render_output(mode, num_frames, start_frame = 0, cache = {})
        input_buffer = render(num_frames, start_frame, cache)

        case mode
        when :mid
          input_buffer.map { |sample| sample * SQRT_TWO }
        when :side
          Array.new(num_frames, 0.0)
        else
          raise ArgumentError, "Unsupported mid/side output: #{mode}"
        end
      end

      def render_output_block(mode, num_frames, start_frame = 0, cache = {})
        input_block = send(:mix_source_blocks, num_frames, start_frame, cache).fit_channels(2)
        left = input_block.channel(0)
        right = input_block.channel(1)

        output = case mode
                 when :mid
                   Array.new(num_frames) { |index| (left[index] + right[index]) / SQRT_TWO }
                 when :side
                   Array.new(num_frames) { |index| (left[index] - right[index]) / SQRT_TWO }
                 else
                   raise ArgumentError, "Unsupported mid/side output: #{mode}"
                 end

        Core::AudioBlock.from_channel_data([output])
      end

      class OutputTap < Core::AudioNode
        def initialize(parent:, mode:, context: Deftones.context)
          super(context: context)
          @parent = parent
          @mode = mode
        end

        def render_block(num_frames, start_frame = 0, cache = {})
          @parent.render_output_block(@mode, num_frames, start_frame, cache)
        end

        def render(num_frames, start_frame = 0, cache = {})
          @parent.render_output(@mode, num_frames, start_frame, cache)
        end
      end
    end
  end
end
