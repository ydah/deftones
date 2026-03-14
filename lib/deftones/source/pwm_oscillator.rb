# frozen_string_literal: true

module Deftones
  module Source
    class PWMOscillator < Core::Source
      attr_reader :frequency, :modulation_frequency, :modulation_depth

      def initialize(frequency: 440.0, modulation_frequency: 0.5, modulation_depth: 0.4,
                     pulse_width: 0.5, context: Deftones.context)
        super(context: context)
        @frequency = Core::Signal.new(value: frequency, units: :frequency, context: context)
        @modulation_frequency = Core::Signal.new(value: modulation_frequency, units: :frequency, context: context)
        @modulation_depth = Core::Signal.new(value: modulation_depth, units: :number, context: context)
        @base_width = pulse_width.to_f
        @phase = 0.0
        @modulation_phase = 0.0
      end

      def process(_input_buffer, num_frames, start_frame, _cache)
        frequencies = @frequency.process(num_frames, start_frame)
        mod_frequencies = @modulation_frequency.process(num_frames, start_frame)
        mod_depths = @modulation_depth.process(num_frames, start_frame)

        Array.new(num_frames) do |index|
          current_time = (start_frame + index).to_f / context.sample_rate
          next 0.0 unless active_at?(current_time)

          width = @base_width + (Math.sin(2.0 * Math::PI * @modulation_phase) * mod_depths[index] * 0.5)
          duty = Deftones::DSP::Helpers.clamp(width, 0.05, 0.95)
          sample = @phase < duty ? 1.0 : -1.0

          @phase = (@phase + (frequencies[index] / context.sample_rate)) % 1.0
          @modulation_phase = (@modulation_phase + (mod_frequencies[index] / context.sample_rate)) % 1.0
          sample
        end
      end
    end
  end
end
