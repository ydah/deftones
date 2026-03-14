# frozen_string_literal: true

module Deftones
  module Effects
    class Reverb < Core::Effect
      attr_accessor :decay, :pre_delay

      def initialize(decay: 0.7, pre_delay: 0.01, context: Deftones.context, **options)
        super(context: context, **options)
        @decay = decay.to_f
        @pre_delay = pre_delay.to_f
        @comb_lines = [0.0297, 0.0371, 0.0411, 0.0437].map do |seconds|
          DSP::DelayLine.new((seconds * context.sample_rate).ceil + 2)
        end
        @comb_times = [0.0297, 0.0371, 0.0411, 0.0437]
        @allpass_lines = [0.005, 0.0017].map do |seconds|
          DSP::DelayLine.new((seconds * context.sample_rate).ceil + 2)
        end
        @allpass_times = [0.005, 0.0017]
        @pre_delay_line = DSP::DelayLine.new((0.1 * context.sample_rate).ceil)
      end

      private

      def process_effect(input_buffer, num_frames, _start_frame, _cache)
        Array.new(num_frames) do |index|
          dry = input_buffer[index]
          delayed = @pre_delay_line.tap(@pre_delay * context.sample_rate, input_sample: dry)
          comb_sum = @comb_lines.each_with_index.sum do |line, comb_index|
            line.tap(@comb_times[comb_index] * context.sample_rate, input_sample: delayed, feedback: @decay)
          end / @comb_lines.length.to_f

          @allpass_lines.each_with_index.reduce(comb_sum) do |sample, (line, allpass_index)|
            tap = line.read(@allpass_times[allpass_index] * context.sample_rate)
            line.write(sample + (tap * 0.5))
            tap - (sample * 0.5)
          end
        end
      end
    end
  end
end
