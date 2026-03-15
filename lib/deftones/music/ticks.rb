# frozen_string_literal: true

module Deftones
  module Music
    class Ticks
      attr_reader :value, :transport

      def initialize(value, transport: Deftones.transport)
        @value = value
        @transport = transport
      end

      def to_i
        self.class.parse(
          value,
          bpm: transport.bpm,
          time_signature: transport.time_signature,
          ppq: transport.ppq
        ).round
      end

      def to_seconds
        transport.ticks_to_seconds(to_i)
      end

      def to_bars_beats_sixteenths
        transport.seconds_to_position(to_seconds)
      end

      def value_of
        to_i
      end

      class << self
        def parse(value, bpm: Deftones.transport.bpm, time_signature: Deftones.transport.time_signature,
                  ppq: Deftones.transport.ppq)
          return value.to_f if value.is_a?(Numeric)

          string_value = value.to_s
          direct_ticks = string_value.match(/\A(-?\d+(?:\.\d+)?)i\z/i)
          return direct_ticks[1].to_f if direct_ticks

          seconds = Time.parse(value, bpm: bpm, time_signature: time_signature, ppq: ppq)
          (seconds / (60.0 / bpm.to_f)) * ppq.to_f
        end
      end
    end
  end
end
