# frozen_string_literal: true

module Deftones
  module Source
    class AMOscillator < Core::Source
      attr_reader :frequency, :harmonicity

      def initialize(frequency: 440.0, harmonicity: 2.0, phase: 0.0, context: Deftones.context)
        super(context: context)
        @frequency = Core::Signal.new(value: frequency, units: :frequency, context: context)
        @harmonicity = Core::Signal.new(value: harmonicity, units: :number, context: context)
        @carrier_phase = phase.to_f % 1.0
        @modulator_phase = phase.to_f % 1.0
      end

      def process(_input_buffer, num_frames, start_frame, _cache)
        frequencies = @frequency.process(num_frames, start_frame)
        harmonicities = @harmonicity.process(num_frames, start_frame)

        Array.new(num_frames) do |index|
          current_time = (start_frame + index).to_f / context.sample_rate
          next 0.0 unless active_at?(current_time)

          carrier_frequency = frequencies[index]
          modulator_frequency = carrier_frequency * harmonicities[index]
          carrier = Math.sin(2.0 * Math::PI * @carrier_phase)
          modulator = (Math.sin(2.0 * Math::PI * @modulator_phase) + 1.0) * 0.5

          @carrier_phase = (@carrier_phase + (carrier_frequency / context.sample_rate)) % 1.0
          @modulator_phase = (@modulator_phase + (modulator_frequency / context.sample_rate)) % 1.0
          carrier * modulator
        end
      end
    end
  end
end
