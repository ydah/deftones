# frozen_string_literal: true

module Deftones
  module Component
    class Follower < Core::AudioNode
      attr_reader :smoothing

      def initialize(smoothing: 0.05, context: Deftones.context)
        super(context: context)
        @smoothing = Core::Signal.new(value: smoothing, units: :time, context: context)
        @state = []
      end

      def smoothing=(value)
        @smoothing.value = value
      end

      def multichannel_process?
        true
      end

      def process(input_block, num_frames, start_frame, _cache)
        smoothing_values = @smoothing.process(num_frames, start_frame)
        ensure_state(input_block.channels)
        output_channels = input_block.channel_data.each_with_index.map do |channel, channel_index|
          Array.new(num_frames) do |index|
            coefficient = smoothing_coefficient(smoothing_values[index])
            magnitude = channel[index].abs
            @state[channel_index] += (1.0 - coefficient) * (magnitude - @state[channel_index])
            @state[channel_index]
          end
        end

        Core::AudioBlock.from_channel_data(output_channels)
      end

      def reset!
        @state = []
        self
      end

      private

      def smoothing_coefficient(duration)
        seconds = [duration.to_f, 1.0 / context.sample_rate].max
        Math.exp(-1.0 / (seconds * context.sample_rate))
      end

      def ensure_state(channels)
        required = [channels.to_i, 1].max
        @state.fill(0.0, @state.length...required)
      end
    end
  end
end
