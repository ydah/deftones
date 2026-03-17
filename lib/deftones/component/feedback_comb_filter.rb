# frozen_string_literal: true

module Deftones
  module Component
    class FeedbackCombFilter < Core::AudioNode
      attr_reader :delay_time, :resonance

      def initialize(delay_time: 0.1, resonance: 0.5, max_delay: 1.0, context: Deftones.context)
        super(context: context)
        @delay_time = Core::Signal.new(value: delay_time, units: :time, context: context)
        @resonance = Core::Signal.new(value: resonance, units: :number, context: context)
        @max_delay_samples = [(max_delay.to_f * context.sample_rate).ceil, 2].max
        @delay_lines = []
      end

      def delay_time=(value)
        @delay_time.value = value
      end

      def resonance=(value)
        @resonance.value = value
      end

      def multichannel_process?
        true
      end

      def process(input_block, num_frames, start_frame, _cache)
        delay_times = @delay_time.process(num_frames, start_frame)
        resonances = @resonance.process(num_frames, start_frame)
        ensure_delay_lines(input_block.channels)

        Core::AudioBlock.from_channel_data(
          input_block.channel_data.each_with_index.map do |channel, channel_index|
            delay_line = @delay_lines[channel_index]

            Array.new(num_frames) do |index|
              delayed = delay_line.read(delay_samples(delay_times[index]))
              feedback = filtered_feedback(delayed, index, start_frame, channel_index)
              delay_line.write(channel[index] + (feedback * clamp_resonance(resonances[index])))
              delayed
            end
          end
        )
      end

      def reset!
        @delay_lines = []
        self
      end

      private

      def delay_samples(duration)
        samples = duration.to_f * context.sample_rate
        [[samples, 1.0].max, @max_delay_samples].min
      end

      def clamp_resonance(value)
        value.to_f.clamp(-0.999, 0.999)
      end

      def filtered_feedback(sample, _index, _start_frame, _channel_index = 0)
        sample
      end

      def ensure_delay_lines(channels)
        required = [channels.to_i, 1].max
        while @delay_lines.length < required
          @delay_lines << DSP::DelayLine.new(@max_delay_samples)
        end
      end
    end
  end
end
