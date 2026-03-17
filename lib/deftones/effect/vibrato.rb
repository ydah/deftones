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
        @delay_line = DSP::DelayLine.new((0.05 * context.sample_rate).ceil)
        initialize_modulation_control
      end

      private

      def process_effect(input_buffer, num_frames, start_frame, _cache)
        Array.new(num_frames) do |index|
          current_time = (start_frame + index).to_f / context.sample_rate
          phase = modulation_phase_for(current_time)
          modulation = unipolar_modulation_value(phase, default: 0.5)
          delay_samples = (0.01 + (@depth * modulation)) * context.sample_rate
          @delay_line.tap(delay_samples, input_sample: input_buffer[index])
        end
      end
    end
  end
end
