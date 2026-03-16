# frozen_string_literal: true

module Deftones
  module Music
    class Frequency
      attr_reader :value

      def initialize(value)
        @value = value
      end

      def to_hz
        self.class.parse(value)
      end

      def to_seconds
        self.class.to_period(value)
      end

      def to_midi
        self.class.to_midi(value)
      end

      def value_of
        to_hz
      end

      class << self
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
