# frozen_string_literal: true

module Deftones
  module Component
    class FrequencyEnvelope < Envelope
      attr_accessor :base_frequency, :octaves

      def initialize(base_frequency: 440.0, octaves: 2.0, **options)
        super(**options)
        @base_frequency = base_frequency.to_f
        @octaves = octaves.to_f
      end

      def values(num_frames, start_frame = 0)
        Array.new(num_frames) do |index|
          time = sample_time(start_frame + index)
          consume_events(time)
          @current_value = envelope_value_at(time)
          @base_frequency * (2.0**(@current_value * @octaves))
        end
      end
    end
  end
end
