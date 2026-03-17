# frozen_string_literal: true

module Deftones
  module Effects
    class Vibrato < Core::Effect
      include ModulationControl

      attr_accessor :frequency, :depth, :type

      def initialize(frequency: 5.0, depth: 0.002, type: :sine, context: Deftones.context, **options)
        super(context: context, wet: 1.0, **options)
        @frequency = frequency.to_f
        @depth = depth.to_f
        @type = normalize_modulation_type(type)
        @phase = 0.0
        @delay_lines = []
        initialize_modulation_control
      end

      private

      def process_effect_block(input_block, num_frames, start_frame, _cache)
        ensure_delay_lines(input_block.channels)
        output = Array.new(input_block.channels) { Array.new(num_frames, 0.0) }

        num_frames.times do |index|
          current_time = (start_frame + index).to_f / context.sample_rate
          phase = modulation_phase_for(current_time)
          modulation = unipolar_modulation_value(phase, default: 0.5)
          delay_samples = (0.01 + (@depth * modulation)) * context.sample_rate
          input_block.channel_data.each_with_index do |channel, channel_index|
            output[channel_index][index] = @delay_lines[channel_index].tap(delay_samples, input_sample: channel[index])
          end
        end

        Core::AudioBlock.from_channel_data(output)
      end

      def ensure_delay_lines(channels)
        required = [channels.to_i, 1].max
        while @delay_lines.length < required
          @delay_lines << DSP::DelayLine.new((0.05 * context.sample_rate).ceil)
        end
      end
    end
  end
end
