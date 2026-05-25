# frozen_string_literal: true

module Deftones
  module Effects
    class Reverb < Core::Effect
      attr_accessor :decay, :pre_delay
      attr_reader :damping, :freeze, :wet_normalization, :width

      def initialize(decay: 0.7, pre_delay: 0.01, damping: 0.0, freeze: false, wet_normalization: false,
                     width: 1.0, context: Deftones.context, **options)
        super(context: context, **options)
        @decay = decay.to_f
        @pre_delay = pre_delay.to_f
        self.damping = damping
        self.freeze = freeze
        self.wet_normalization = wet_normalization
        self.width = width
        @comb_times = [0.0297, 0.0371, 0.0411, 0.0437]
        @allpass_times = [0.005, 0.0017]
        @comb_lines = []
        @comb_damping_state = []
        @allpass_lines = []
        @pre_delay_lines = []
      end

      def damping=(value)
        @damping = value.to_f.clamp(0.0, 1.0)
      end

      def freeze=(value)
        @freeze = !!value
      end

      def wet_normalization=(value)
        @wet_normalization = !!value
      end

      def width=(value)
        @width = value.to_f.clamp(0.0, 1.0)
      end

      alias dampening damping
      alias dampening= damping=
      alias wetNormalization wet_normalization
      alias wetNormalization= wet_normalization=

      private

      def process_effect_block(input_block, num_frames, start_frame, cache)
        output_channels = [input_block.channels, 2].max
        source = input_block.fit_channels(output_channels)

        Core::AudioBlock.from_channel_data(
          apply_stereo_width(source.channel_data.each_with_index.map do |channel, channel_index|
            process_effect(channel, num_frames, start_frame, cache, channel_index: channel_index)
          end)
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
          feedback = effective_decay
          comb_input = @freeze ? 0.0 : delayed
          comb_sum = comb_lines.each_with_index.sum do |line, comb_index|
            process_comb(line, comb_times[comb_index] * context.sample_rate, comb_input, feedback, channel_index,
                         comb_index)
          end / comb_lines.length.to_f

          wet_sample = allpass_lines.each_with_index.reduce(comb_sum) do |sample, (line, allpass_index)|
            tap = line.read(allpass_times[allpass_index] * context.sample_rate)
            line.write(sample + (tap * 0.5))
            tap - (sample * 0.5)
          end
          normalize_wet_sample(wet_sample, feedback)
        end
      end

      def process_comb(line, delay_samples, input_sample, feedback, channel_index, comb_index)
        delayed_sample = line.read(delay_samples)
        previous = @comb_damping_state[channel_index][comb_index]
        filtered = DSP::Helpers.lerp(delayed_sample, previous, @damping)
        @comb_damping_state[channel_index][comb_index] = filtered
        line.write(input_sample + (filtered * feedback))
        filtered
      end

      def ensure_delay_network(channel_index)
        required = [channel_index.to_i, 0].max
        while @pre_delay_lines.length <= required
          @pre_delay_lines << DSP::DelayLine.new((0.1 * context.sample_rate).ceil)
          @comb_lines << @comb_times.map { |seconds| DSP::DelayLine.new((seconds * context.sample_rate).ceil + 2) }
          @comb_damping_state << Array.new(@comb_times.length, 0.0)
          @allpass_lines << @allpass_times.map { |seconds| DSP::DelayLine.new((seconds * context.sample_rate).ceil + 2) }
        end
      end

      def channel_times(times, channel_index, offset)
        return times if channel_index.zero?

        times.map { |time| time + (offset * channel_index) }
      end

      def apply_stereo_width(channel_data)
        return channel_data if channel_data.length < 2 || @width >= 1.0

        left = channel_data[0]
        right = channel_data[1]
        widened_left = []
        widened_right = []
        left.each_index do |index|
          mid = (left[index] + right[index]) * 0.5
          side = (left[index] - right[index]) * 0.5 * @width
          widened_left << (mid + side)
          widened_right << (mid - side)
        end
        [widened_left, widened_right] + channel_data.drop(2)
      end

      def effective_decay
        @freeze ? 0.995 : @decay.to_f.clamp(0.0, 0.995)
      end

      def normalize_wet_sample(sample, feedback)
        return sample unless @wet_normalization

        sample * (1.0 - ([feedback.abs, 0.95].min * 0.35))
      end
    end
  end
end
