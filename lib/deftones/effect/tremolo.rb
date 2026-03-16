# frozen_string_literal: true

module Deftones
  module Effects
    class Tremolo < Core::Effect
      include ModulationControl

      attr_accessor :frequency, :depth

      def initialize(frequency: 5.0, depth: 0.8, context: Deftones.context, **options)
        super(context: context, wet: 1.0, **options)
        @frequency = frequency.to_f
        @depth = depth.to_f
        @phase = 0.0
        initialize_modulation_control
      end

      private

      def process_effect(input_buffer, num_frames, start_frame, _cache)
        Array.new(num_frames) do |index|
          current_time = (start_frame + index).to_f / context.sample_rate
          phase = modulation_phase_for(current_time)
          modulation = phase ? ((Math.sin(2.0 * Math::PI * phase) + 1.0) * 0.5) : 1.0
          input_buffer[index] * (1.0 - (@depth * (1.0 - modulation)))
        end
      end
    end
  end
end
