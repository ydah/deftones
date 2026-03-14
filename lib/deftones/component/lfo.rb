# frozen_string_literal: true

module Deftones
  module Component
    class LFO < Source::Oscillator
      attr_accessor :min, :max

      def initialize(frequency: 1.0, min: 0.0, max: 1.0, type: :sine, context: Deftones.context)
        super(type: type, frequency: frequency, context: context)
        @min = min.to_f
        @max = max.to_f
      end

      def values(num_frames, start_frame = 0, cache = {})
        range = @max - @min

        render(num_frames, start_frame, cache).map do |sample|
          @min + (((sample + 1.0) * 0.5) * range)
        end
      end
    end
  end
end
