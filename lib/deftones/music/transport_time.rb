# frozen_string_literal: true

module Deftones
  module Music
    class TransportTime
      attr_reader :value, :transport

      def initialize(value, transport: Deftones.transport)
        @value = value
        @transport = transport
      end

      def to_seconds
        self.class.parse(
          value,
          bpm: transport.bpm,
          time_signature: transport.time_signature,
          ppq: transport.ppq
        )
      end

      def to_ticks
        transport.seconds_to_ticks(to_seconds)
      end

      def to_bars_beats_sixteenths
        transport.seconds_to_position(to_seconds)
      end

      def value_of
        to_seconds
      end

      class << self
        def parse(value, bpm: Deftones.transport.bpm, time_signature: Deftones.transport.time_signature,
                  ppq: Deftones.transport.ppq)
          Time.parse(value, bpm: bpm, time_signature: time_signature, ppq: ppq)
        end
      end
    end
  end
end
