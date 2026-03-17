# frozen_string_literal: true

module Deftones
  module Effects
    class Reverb < Core::Effect
      attr_accessor :decay, :pre_delay

      def initialize(decay: 0.7, pre_delay: 0.01, context: Deftones.context, **options)
        super(context: context, **options)
        @decay = decay.to_f
        @pre_delay = pre_delay.to_f
        @comb_times = [0.0297, 0.0371, 0.0411, 0.0437]
        @allpass_times = [0.005, 0.0017]
        @comb_lines = []
        @allpass_lines = []
        @pre_delay_lines = []
      end

      private

      def process_effect_block(input_block, num_frames, start_frame, cache)
        output_channels = [input_block.channels, 2].max
        source = input_block.fit_channels(output_channels)

        Core::AudioBlock.from_channel_data(
          source.channel_data.each_with_index.map do |channel, channel_index|
            process_effect(channel, num_frames, start_frame, cache, channel_index: channel_index)
          end
        )
      end

      def process_effect(input_buffer, num_frames, _start_frame, _cache, channel_index: 0)
        ensure_delay_network(channel_index)
        pre_delay_line = @pre_delay_lines[channel_index]
        comb_lines = @comb_lines[channel_index]
        allpass_lines = @allpass_lines[channel_index]
        comb_times = channel_times(@comb_times, channel_index, 0.00037)
        allpass_times = channel_times(@allpass_times, channel_index, 0.00011)

        Array.new(num_frames) do |index|
          dry = input_buffer[index]
          delayed = pre_delay_line.tap(@pre_delay * context.sample_rate, input_sample: dry)
          comb_sum = comb_lines.each_with_index.sum do |line, comb_index|
            line.tap(comb_times[comb_index] * context.sample_rate, input_sample: delayed, feedback: @decay)
          end / comb_lines.length.to_f

          allpass_lines.each_with_index.reduce(comb_sum) do |sample, (line, allpass_index)|
            tap = line.read(allpass_times[allpass_index] * context.sample_rate)
            line.write(sample + (tap * 0.5))
            tap - (sample * 0.5)
          end
        end
      end

      def ensure_delay_network(channel_index)
        required = [channel_index.to_i, 0].max
        while @pre_delay_lines.length <= required
          @pre_delay_lines << DSP::DelayLine.new((0.1 * context.sample_rate).ceil)
          @comb_lines << @comb_times.map { |seconds| DSP::DelayLine.new((seconds * context.sample_rate).ceil + 2) }
          @allpass_lines << @allpass_times.map { |seconds| DSP::DelayLine.new((seconds * context.sample_rate).ceil + 2) }
        end
      end

      def channel_times(times, channel_index, offset)
        return times if channel_index.zero?

        times.map { |time| time + (offset * channel_index) }
      end
    end
  end
end
