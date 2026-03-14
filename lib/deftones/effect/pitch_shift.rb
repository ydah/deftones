# frozen_string_literal: true

module Deftones
  module Effects
    class PitchShift < Core::Effect
      attr_accessor :semitones

      def initialize(semitones: 0.0, window: 0.1, context: Deftones.context, **options)
        super(context: context, **options)
        @semitones = semitones.to_f
        @buffer = Array.new((window * context.sample_rate).ceil, 0.0)
        @write_index = 0
        @read_index = 0.0
      end

      private

      def process_effect(input_buffer, num_frames, _start_frame, _cache)
        ratio = 2.0**(@semitones / 12.0)

        Array.new(num_frames) do |index|
          @buffer[@write_index] = input_buffer[index]
          sample = read_buffer(@read_index)
          @write_index = (@write_index + 1) % @buffer.length
          @read_index = (@read_index + ratio) % @buffer.length
          sample
        end
      end

      def read_buffer(position)
        lower = position.floor % @buffer.length
        upper = (lower + 1) % @buffer.length
        fraction = position - position.floor
        DSP::Helpers.lerp(@buffer[lower], @buffer[upper], fraction)
      end
    end
  end
end
