# frozen_string_literal: true

module Deftones
  module Effects
    class AutoWah < Core::Effect
      attr_accessor :base_frequency, :octaves, :q

      def initialize(base_frequency: 200.0, octaves: 4.0, q: 2.0, context: Deftones.context, **options)
        super(context: context, wet: 1.0, **options)
        @base_frequency = base_frequency.to_f
        @octaves = octaves.to_f
        @q = q.to_f
        @envelope = 0.0
        @filter = DSP::Biquad.new
      end

      private

      def process_effect(input_buffer, num_frames, _start_frame, _cache)
        Array.new(num_frames) do |index|
          sample = input_buffer[index]
          @envelope = (0.995 * @envelope) + (0.005 * sample.abs)
          cutoff = @base_frequency * (2.0**(@octaves * @envelope))
          @filter.update(type: :bandpass, frequency: cutoff, q: @q, gain_db: 0.0, sample_rate: context.sample_rate)
          @filter.process_sample(sample)
        end
      end
    end
  end
end
