# frozen_string_literal: true

module Deftones
  module Source
    class FMOscillator < Core::Source
      attr_reader :frequency, :harmonicity, :modulation_index

      def initialize(frequency: 440.0, harmonicity: 2.0, modulation_index: 5.0,
                     phase: 0.0, context: Deftones.context)
        super(context: context)
        @frequency = Core::Signal.new(value: frequency, units: :frequency, context: context)
        @harmonicity = Core::Signal.new(value: harmonicity, units: :number, context: context)
        @modulation_index = Core::Signal.new(value: modulation_index, units: :number, context: context)
        @carrier_phase = phase.to_f % 1.0
        @modulator_phase = phase.to_f % 1.0
      end

      def process(_input_buffer, num_frames, start_frame, _cache)
        frequencies = @frequency.process(num_frames, start_frame)
        harmonicities = @harmonicity.process(num_frames, start_frame)
        modulation_indices = @modulation_index.process(num_frames, start_frame)

        Array.new(num_frames) do |index|
          current_time = (start_frame + index).to_f / context.sample_rate
          next 0.0 unless active_at?(current_time)

          carrier_frequency = frequencies[index]
          modulator_frequency = carrier_frequency * harmonicities[index]
          modulation = Math.sin(2.0 * Math::PI * @modulator_phase) * modulation_indices[index]
          sample = Math.sin((2.0 * Math::PI * @carrier_phase) + modulation)

          @carrier_phase = (@carrier_phase + (carrier_frequency / context.sample_rate)) % 1.0
          @modulator_phase = (@modulator_phase + (modulator_frequency / context.sample_rate)) % 1.0
          sample
        end
      end
    end
  end
end
