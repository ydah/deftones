# frozen_string_literal: true

module Deftones
  module Core
    class Delay < AudioNode
      attr_reader :delay_time, :max_delay

      def initialize(delay_time: 0.0, max_delay: 1.0, context: Deftones.context)
        super(context: context)
        @delay_time = Signal.new(value: delay_time, units: :time, context: context)
        @max_delay = [max_delay.to_f, @delay_time.value].max
        @delay_lines = []
      end

      def multichannel_process?
        true
      end

      def process(input_block, num_frames, start_frame, _cache)
        delay_values = @delay_time.process(num_frames, start_frame)
        AudioBlock.from_channel_data(
          input_block.channel_data.each_with_index.map do |channel, channel_index|
            delay_line = ensure_delay_line(channel_index)
            Array.new(num_frames) do |index|
              delay_seconds = [delay_values[index], 0.0].max
              delay_samples = [delay_seconds * context.sample_rate, @max_delay * context.sample_rate].min
              delay_line.tap(delay_samples, input_sample: channel[index], feedback: 0.0)
            end
          end
        )
      end

      private

      def ensure_delay_line(channel_index)
        required = [channel_index.to_i, 0].max
        while @delay_lines.length <= required
          @delay_lines << DSP::DelayLine.new((@max_delay * context.sample_rate).ceil)
        end
        @delay_lines[required]
      end
    end
  end
end
