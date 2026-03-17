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

      def process_effect(input_buffer, num_frames, start_frame, _cache)
        Array.new(num_frames) do |index|
          current_time = (start_frame + index).to_f / context.sample_rate
          phase = modulation_phase_for(current_time)
          input_buffer[index] * tremolo_gain(phase)
        end
      end

      def tremolo_gain(phase)
        primary = channel_gain_for_phase(phase)
        secondary_phase = phase.nil? ? nil : phase + (@spread / 360.0)
        secondary = channel_gain_for_phase(secondary_phase)
        (primary + secondary) * 0.5
      end

      def channel_gain_for_phase(phase)
        modulation = unipolar_modulation_value(phase, default: 1.0)
        1.0 - (@depth * (1.0 - modulation))
      end
    end
  end
end
