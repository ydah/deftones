# frozen_string_literal: true

module Deftones
  module Effects
    class Tremolo < Core::Effect
      include ModulationControl

      attr_accessor :frequency, :depth, :spread, :type

      def initialize(frequency: 5.0, depth: 0.8, spread: 0.0, type: :sine, context: Deftones.context, **options)
        super(context: context, wet: 1.0, **options)
        @frequency = frequency.to_f
        @depth = depth.to_f
        @spread = spread.to_f
        @type = normalize_modulation_type(type)
        @phase = 0.0
        initialize_modulation_control
      end

      private

      def process_effect_block(input_block, num_frames, start_frame, _cache)
        output_channels = [input_block.channels, 2].max
        source = input_block.fit_channels(output_channels)
        output = Array.new(output_channels) { Array.new(num_frames, 0.0) }

        num_frames.times do |index|
          current_time = (start_frame + index).to_f / context.sample_rate
          base_phase = modulation_phase_for(current_time)

          output_channels.times do |channel_index|
            phase = base_phase.nil? ? nil : base_phase + channel_phase_offset(channel_index, output_channels)
            output[channel_index][index] = source.channel_data[channel_index][index] * channel_gain_for_phase(phase)
          end
        end

        Core::AudioBlock.from_channel_data(output)
      end

      def channel_phase_offset(channel_index, channels)
        return 0.0 if channels <= 1

        (@spread / 360.0) * (channel_index.to_f / [channels - 1, 1].max)
      end

      def channel_gain_for_phase(phase)
        modulation = unipolar_modulation_value(phase, default: 1.0)
        1.0 - (@depth * (1.0 - modulation))
      end
    end
  end
end
