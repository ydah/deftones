# frozen_string_literal: true

module Deftones
  module Music
    class TransportTime
      attr_reader :value, :transport

      def initialize(value, transport: Deftones.transport)
        @value = value
        @transport = transport
        @disposed = false
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

      def to_frequency
        1.0 / [to_seconds, 1.0e-6].max
      end

      def to_midi
        Note.to_midi(Note.from_frequency(to_frequency))
      end

      def to_milliseconds
        to_seconds * 1000.0
      end

      def to_samples(sample_rate = Deftones.context.sample_rate)
        UnitHelpers.samples_for_seconds(to_seconds, sample_rate)
      end

      def to_notation
        UnitHelpers.closest_notation(to_seconds, transport: transport)
      end

      def quantize(subdiv, percent = 1.0)
        UnitHelpers.quantize_seconds(to_seconds, subdiv, transport: transport, percent: percent)
      end

      def from_type(type)
        @value =
          if type.respond_to?(:to_bars_beats_sixteenths)
            type.to_bars_beats_sixteenths
          elsif type.respond_to?(:value_of)
            type.value_of
          else
            type
          end
        self
      end

      def dispose
        @disposed = true
        self
      end

      def disposed?
        @disposed
      end

      def to_s
        value.to_s
      end

      alias toString to_s

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
