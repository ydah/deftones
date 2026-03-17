# frozen_string_literal: true

module Deftones
  module Effects
    class AutoPanner < Core::Effect
      include ModulationControl

      attr_accessor :frequency, :depth, :type

      def initialize(frequency: 2.0, depth: 0.5, type: :sine, context: Deftones.context, **options)
        super(context: context, wet: 1.0, **options)
        @frequency = frequency.to_f
        @depth = depth.to_f
        @type = normalize_modulation_type(type)
        @phase = 0.0
        initialize_modulation_control
      end

      private

      def process_effect_block(input_block, num_frames, start_frame, _cache)
        output = Array.new(2) { Array.new(num_frames, 0.0) }
        stereo_input = input_block.fit_channels(2)
        mono_input = input_block.mono

        num_frames.times do |index|
          current_time = (start_frame + index).to_f / context.sample_rate
          phase = modulation_phase_for(current_time)
          modulation = bipolar_modulation_value(phase, default: 0.0) * @depth.clamp(0.0, 1.0)
          if input_block.channels == 1
            sample = mono_input[index]
            output[0][index] = sample * left_gain(modulation)
            output[1][index] = sample * right_gain(modulation)
            next
          end

          output[0][index] = stereo_input.channel_data[0][index] * left_gain(modulation)
          output[1][index] = stereo_input.channel_data[1][index] * right_gain(modulation)
        end

        Core::AudioBlock.from_channel_data(output)
      end

      def left_gain(pan)
        Math.cos(angle_for(pan))
      end

      def right_gain(pan)
        Math.sin(angle_for(pan))
      end

      def angle_for(pan)
        ((pan.to_f.clamp(-1.0, 1.0) + 1.0) * Math::PI) * 0.25
      end
    end
  end
end
