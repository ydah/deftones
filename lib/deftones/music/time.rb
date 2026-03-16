# frozen_string_literal: true

module Deftones
  module Music
    class Time
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

      SYMBOL_MAP = {
        whole: "1n",
        half: "2n",
        quarter: "4n",
        eighth: "8n",
        sixteenth: "16n",
        quarter_triplet: "4t",
        eighth_triplet: "8t",
        dotted_quarter: "4n.",
        dotted_eighth: "8n.",
        measure: "1m"
      }.freeze

      class << self
        def parse(value, bpm: Deftones.transport.bpm, time_signature: Deftones.transport.time_signature,
                  ppq: Deftones.transport.ppq)
          case value
          when Numeric
            value.to_f
          when Symbol
            parse(SYMBOL_MAP.fetch(value), bpm: bpm, time_signature: time_signature, ppq: ppq)
          when String
            return evaluate_expression(value, bpm: bpm, time_signature: time_signature, ppq: ppq) if arithmetic_expression?(value)

            parse_literal(value, bpm: bpm, time_signature: time_signature, ppq: ppq)
          when /\A(\d+)n\z/
            parse_literal(value, bpm: bpm, time_signature: time_signature, ppq: ppq)
          else
            return value.to_seconds if value.respond_to?(:to_seconds)
          end
        rescue KeyError, ArgumentError
          raise ArgumentError, "Unknown time format: #{value}"
        end

        private

        def parse_literal(value, bpm:, time_signature:, ppq:)
          case value
          when /\A(\d+)n\z/
            beats = 4.0 / Regexp.last_match(1).to_f
            beats * beat_duration(bpm)
          when /\A(\d+)t\z/
            beats = (4.0 / Regexp.last_match(1).to_f) * (2.0 / 3.0)
            beats * beat_duration(bpm)
          when /\A(\d+)n\.\z/
            parse("#{Regexp.last_match(1)}n", bpm: bpm, time_signature: time_signature, ppq: ppq) * 1.5
          when /\A(\d+)m\z/i
            measures = Regexp.last_match(1).to_f
            beats_per_measure = Array(time_signature).first || 4
            measures * beats_per_measure * beat_duration(bpm)
          when /\A(\d+):(\d+):(\d+)\z/
            bars = Regexp.last_match(1).to_f
            beats = Regexp.last_match(2).to_f
            sixteenths = Regexp.last_match(3).to_f
            beats_per_measure = Array(time_signature).first || 4
            ((bars * beats_per_measure) + beats + (sixteenths * 0.25)) * beat_duration(bpm)
          when /\A(\d+(?:\.\d+)?)hz\z/i
            1.0 / Regexp.last_match(1).to_f
          when /\A(-?\d+(?:\.\d+)?)i\z/i
            (Regexp.last_match(1).to_f / ppq.to_f) * beat_duration(bpm)
          else
            Float(value)
          end
        end

        def arithmetic_expression?(value)
          value.match?(/[+\-*\/()]/) && !value.match?(/\A-?\d+(?:\.\d+)?\z/)
        end

        def beat_duration(bpm)
          60.0 / bpm.to_f
        end

        def evaluate_expression(value, bpm:, time_signature:, ppq:)
          compute_rpn(to_rpn(tokenize(value)), bpm: bpm, time_signature: time_signature, ppq: ppq)
        end

        def tokenize(expression)
          expression.scan(/\d+:\d+:\d+|\d+(?:\.\d+)?hz|-?\d+(?:\.\d+)?i|\d+n\.?|\d+t|\d+m|[()+\-*\/]|\d+(?:\.\d+)?/)
        end

        def to_rpn(tokens)
          output = []
          operators = []

          tokens.each do |token|
            if operator?(token)
              while operators.any? && operator?(operators.last) && precedence(operators.last) >= precedence(token)
                output << operators.pop
              end
              operators << token
            elsif token == "("
              operators << token
            elsif token == ")"
              output << operators.pop until operators.last == "("
              operators.pop
            else
              output << token
            end
          end

          output.concat(operators.reverse)
        end

        def compute_rpn(tokens, bpm:, time_signature:, ppq:)
          stack = []

          tokens.each do |token|
            if operator?(token)
              right = stack.pop
              left = stack.pop
              stack << left.public_send(token, right)
            else
              stack << parse_literal(token, bpm: bpm, time_signature: time_signature, ppq: ppq)
            end
          end

          stack.first
        end

        def operator?(token)
          %w[+ - * /].include?(token)
        end

        def precedence(token)
          %w[* /].include?(token) ? 2 : 1
        end
      end
    end
  end
end
