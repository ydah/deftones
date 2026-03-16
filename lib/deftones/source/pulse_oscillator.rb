# frozen_string_literal: true

module Deftones
  module Source
    class PulseOscillator < Core::Source
      attr_reader :frequency, :width, :detune

      def initialize(frequency: 440.0, width: 0.5, detune: 0.0, phase: 0.0, context: Deftones.context)
        super(context: context)
        @frequency = Core::Signal.new(value: frequency, units: :frequency, context: context)
        @width = Core::Signal.new(value: width, units: :number, context: context)
        @detune = Core::Signal.new(value: detune, units: :number, context: context)
        @phase = phase.to_f % 1.0
      end

      def detune=(value)
        @detune.value = value
      end

      def process(_input_buffer, num_frames, start_frame, _cache)
        frequencies = @frequency.process(num_frames, start_frame)
        widths = @width.process(num_frames, start_frame)
        detunes = @detune.process(num_frames, start_frame)

        Array.new(num_frames) do |index|
          current_time = (start_frame + index).to_f / context.sample_rate
          next 0.0 unless active_at?(current_time)

          duty = Deftones::DSP::Helpers.clamp(widths[index], 0.01, 0.99)
          sample = @phase < duty ? 1.0 : -1.0
          frequency = frequencies[index] * (2.0**(detunes[index].to_f / 1200.0))
          @phase = (@phase + (frequency / context.sample_rate)) % 1.0
          sample
        end
      end
    end
  end
end
