# frozen_string_literal: true

module Deftones
  module Analysis
    class DCMeter < Core::AudioNode
      def initialize(smoothing: 0.8, channels: 1, context: Deftones.context)
        super(context: context)
        @channels = [channels.to_i, 1].max
        @offsets = Array.new(@channels, 0.0)
        self.smoothing = smoothing
      end

      def offset
        @offsets.length == 1 ? @offsets.first : @offsets.dup
      end

      def smoothing
        @smoothing
      end

      def smoothing=(value)
        @smoothing = Deftones::DSP::Helpers.clamp(value.to_f, 0.0, 1.0)
      end

      def get_value
        @offsets.length == 1 ? @offsets.first : @offsets.dup
      end

      def multichannel_process?
        true
      end

      def process(input_block, num_frames, _start_frame, _cache)
        analysis_block = input_block.fit_channels(@channels)

        @channels.times do |channel_index|
          segment = analysis_block.channel_data[channel_index].first(num_frames)
          instantaneous_offset = segment.sum / [segment.length, 1].max
          @offsets[channel_index] = smooth(@offsets[channel_index], instantaneous_offset)
        end

        input_block
      end

      alias getValue get_value

      private

      def smooth(previous, current)
        return current if @smoothing.zero?

        (previous.to_f * @smoothing) + (current.to_f * (1.0 - @smoothing))
      end
    end
  end
end
