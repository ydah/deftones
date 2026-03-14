# frozen_string_literal: true

module Deftones
  module Source
    class FatOscillator < Core::Source
      attr_reader :frequency
      attr_accessor :count, :spread, :type

      def initialize(type: :sawtooth, frequency: 440.0, count: 3, spread: 20.0, context: Deftones.context)
        super(context: context)
        @type = type.to_sym
        @frequency = Core::Signal.new(value: frequency, units: :frequency, context: context)
        @count = count.to_i
        @spread = spread.to_f
        @phases = Array.new(@count, 0.0)
      end

      def process(_input_buffer, num_frames, start_frame, _cache)
        frequencies = @frequency.process(num_frames, start_frame)
        generator = Oscillator::GENERATORS.fetch(@type) { Oscillator::GENERATORS[:sawtooth] }

        Array.new(num_frames) do |index|
          current_time = (start_frame + index).to_f / context.sample_rate
          next 0.0 unless active_at?(current_time)

          detuned = detune_frequencies(frequencies[index])
          samples = @phases.each_with_index.map do |phase, voice_index|
            sample = generator.call(phase)
            @phases[voice_index] = (phase + (detuned[voice_index] / context.sample_rate)) % 1.0
            sample
          end
          samples.sum / samples.length.to_f
        end
      end

      private

      def detune_frequencies(base_frequency)
        offsets = Array.new(@count) do |index|
          position = @count == 1 ? 0.0 : (index.to_f / (@count - 1)) - 0.5
          cents = position * @spread
          base_frequency * (2.0**(cents / 1200.0))
        end
        @phases = Array.new(@count, 0.0) if @phases.length != @count
        offsets
      end
    end
  end
end
