# frozen_string_literal: true

module Deftones
  module Component
    class Merge < Core::AudioNode
      attr_reader :input, :output, :left, :right

      def initialize(context: Deftones.context)
        super(context: context)
        @left = Core::Gain.new(context: context)
        @right = Core::Gain.new(context: context)
        @input = @left
        @output = self
      end

      def number_of_inputs
        2
      end

      alias numberOfInputs number_of_inputs

      def input_for_index(index)
        case index
        when 0 then @left
        when 1 then @right
        else raise_connection_index_error!(:input_index, index, number_of_inputs)
        end
      end

      def render(num_frames, start_frame = 0, cache = {})
        cache_key = [object_id, start_frame, num_frames]
        return cache.fetch(cache_key).dup if cache.key?(cache_key)

        left_buffer = @left.render(num_frames, start_frame, cache)
        right_buffer = @right.render(num_frames, start_frame, cache)
        output_buffer = Array.new(num_frames) do |index|
          (left_buffer[index] + right_buffer[index]) * 0.5
        end

        cache[cache_key] = output_buffer
        output_buffer.dup
      end

      def render_block(num_frames, start_frame = 0, cache = {})
        cache_key = [object_id, :block, start_frame, num_frames]
        return cache.fetch(cache_key).dup if cache.key?(cache_key)

        left_block = @left.send(:render_block, num_frames, start_frame, cache)
        right_block = @right.send(:render_block, num_frames, start_frame, cache)
        output_block = Core::AudioBlock.from_channel_data([
          left_block.mono,
          right_block.mono
        ])
        cache[cache_key] = output_block
        output_block.dup
      end
    end
  end
end
