# frozen_string_literal: true

module Deftones
  module Music
    class Frequency
      attr_reader :value, :transport

      def initialize(value, transport: Deftones.transport)
        @value = value
        @transport = transport
        @disposed = false
      end

      def to_hz
        self.class.parse(value)
      end

      def to_frequency
        to_hz
      end

      def to_seconds
        self.class.to_period(value)
      end

      def to_midi
        self.class.to_midi(value)
      end

      def to_ticks
        transport.seconds_to_ticks(to_seconds)
      end

      def to_bars_beats_sixteenths
        transport.seconds_to_position(to_seconds)
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

      def to_note
        Note.from_frequency(to_hz)
      end

      def transpose(interval)
        self.class.new(Note.from_midi(to_midi + interval.to_i), transport: transport)
      end

      def harmonize(intervals)
        Array(intervals).map { |interval| transpose(interval) }
      end

      def quantize(subdiv, percent = 1.0)
        quantized_seconds = UnitHelpers.quantize_seconds(to_seconds, subdiv, transport: transport, percent: percent)
        1.0 / [quantized_seconds, 1.0e-6].max
      end

      def from_type(type)
        @value =
          if type.respond_to?(:to_frequency)
            type.to_frequency
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
        to_hz
      end

      class << self
        def mtof(value)
          Deftones.mtof(value)
        end

        def ftom(value)
          Deftones.ftom(value)
        end

        def parse(value)
          case value
          when Numeric
            value.to_f
          when /\A(\d+(?:\.\d+)?)hz\z/i
            Regexp.last_match(1).to_f
          else
            Note.to_frequency(value)
          end
        end

        def to_period(value)
          1.0 / parse(value)
        end

        def to_midi(value)
          Note.to_midi(Note.from_frequency(parse(value)))
        end
      end
    end
  end
end
