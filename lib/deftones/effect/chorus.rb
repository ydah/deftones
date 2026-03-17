# frozen_string_literal: true

module Deftones
  module Effects
    class Chorus < Core::Effect
      include ModulationControl

      attr_accessor :frequency, :depth, :delay_time, :feedback, :spread, :type

      def initialize(
        frequency: 1.5,
        depth: 0.003,
        delay_time: 0.015,
        feedback: 0.0,
        spread: 180.0,
        type: :sine,
        context: Deftones.context,
        **options
      )
        super(context: context, **options)
        @frequency = frequency.to_f
        @depth = depth.to_f
        @delay_time = delay_time.to_f
        @feedback = feedback.to_f
        @spread = spread.to_f
        @type = normalize_modulation_type(type)
        @phase = 0.0
        @primary_delay_line = DSP::DelayLine.new((0.1 * context.sample_rate).ceil)
        @secondary_delay_line = DSP::DelayLine.new((0.1 * context.sample_rate).ceil)
        initialize_modulation_control
      end

      private

      def process_effect(input_buffer, num_frames, start_frame, _cache)
        Array.new(num_frames) do |index|
          current_time = (start_frame + index).to_f / context.sample_rate
          phase = modulation_phase_for(current_time)
          primary_modulation = unipolar_modulation_value(phase, default: 0.5)
          secondary_phase = phase.nil? ? nil : phase + (@spread / 360.0)
          secondary_modulation = unipolar_modulation_value(secondary_phase, default: 0.5)
          primary_delay = (@delay_time + (@depth * primary_modulation)) * context.sample_rate
          secondary_delay = (@delay_time + (@depth * secondary_modulation)) * context.sample_rate
          primary = @primary_delay_line.tap(primary_delay, input_sample: input_buffer[index], feedback: @feedback)
          secondary = @secondary_delay_line.tap(secondary_delay, input_sample: input_buffer[index], feedback: @feedback)
          (primary + secondary) * 0.5
        end
      end
    end
  end
end
