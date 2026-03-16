# frozen_string_literal: true

module Deftones
  module Effects
    class Phaser < Core::Effect
      include ModulationControl

      attr_accessor :frequency, :octaves, :q

      def initialize(frequency: 0.5, octaves: 3.0, q: 0.8, context: Deftones.context, **options)
        super(context: context, **options)
        @frequency = frequency.to_f
        @octaves = octaves.to_f
        @q = q.to_f
        @phase = 0.0
        @filter = DSP::Biquad.new
        initialize_modulation_control
      end

      private

      def process_effect(input_buffer, num_frames, start_frame, _cache)
        Array.new(num_frames) do |index|
          current_time = (start_frame + index).to_f / context.sample_rate
          phase = modulation_phase_for(current_time)
          modulation = phase ? ((Math.sin(2.0 * Math::PI * phase) + 1.0) * 0.5) : 0.5
          cutoff = 300.0 * (2.0**(modulation * @octaves))
          @filter.update(type: :notch, frequency: cutoff, q: @q, gain_db: 0.0, sample_rate: context.sample_rate)
          @filter.process_sample(input_buffer[index])
        end
      end
    end
  end
end
