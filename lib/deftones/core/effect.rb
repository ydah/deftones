# frozen_string_literal: true

module Deftones
  module Core
    class Effect < AudioNode
      attr_reader :wet

      def initialize(wet: 1.0, context: Deftones.context)
        super(context: context)
        @wet = Signal.new(value: wet, units: :number, context: context)
      end

      def wet=(value)
        @wet.value = value
      end

      def multichannel_process?
        true
      end

      def process(input_block, num_frames, start_frame, cache)
        wet_values = @wet.process(num_frames, start_frame)
        wet_block = process_effect_block(input_block.dup, num_frames, start_frame, cache)
        output_channels = [input_block.channels, wet_block.channels].max
        dry_block = input_block.fit_channels(output_channels)
        wet_block = wet_block.fit_channels(output_channels)

        AudioBlock.from_channel_data(
          Array.new(output_channels) do |channel_index|
            Array.new(num_frames) do |frame_index|
              DSP::Helpers.mix(
                dry_block.channel_data[channel_index][frame_index],
                wet_block.channel_data[channel_index][frame_index],
                wet_values[frame_index].clamp(0.0, 1.0)
              )
            end
          end
        )
      end

      private

      def process_effect_block(input_block, num_frames, start_frame, cache)
        AudioBlock.from_channel_data(
          input_block.channel_data.each_with_index.map do |channel, channel_index|
            normalize_channel_output(
              process_effect(channel, num_frames, start_frame, cache, channel_index: channel_index),
              num_frames
            )
          end
        )
      end

      def process_effect(input_buffer, _num_frames, _start_frame, _cache, channel_index: 0)
        input_buffer
      end

      def normalize_channel_output(output, num_frames)
        normalized = Array(output).map(&:to_f)
        return normalized.first(num_frames) if normalized.length >= num_frames

        normalized + Array.new(num_frames - normalized.length, 0.0)
      end
    end
  end
end
