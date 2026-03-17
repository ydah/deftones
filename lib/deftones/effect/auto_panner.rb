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

      def process_effect(input_buffer, num_frames, start_frame, _cache)
        Array.new(num_frames) do |index|
          current_time = (start_frame + index).to_f / context.sample_rate
          phase = modulation_phase_for(current_time)
          modulation = bipolar_modulation_value(phase, default: 0.0) * @depth.clamp(0.0, 1.0)
          input_buffer[index] * fold_down_gain(modulation)
        end
      end

      def fold_down_gain(pan)
        normalized = pan.to_f.clamp(-1.0, 1.0)
        angle = ((normalized + 1.0) * Math::PI) * 0.25
        (Math.cos(angle) + Math.sin(angle)) * 0.5
      end
    end
  end
end
