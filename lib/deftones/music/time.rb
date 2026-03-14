# frozen_string_literal: true

module Deftones
  module Music
    class Time
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
        def parse(value, bpm: Deftones.transport.bpm, time_signature: Deftones.transport.time_signature)
          case value
          when Numeric
            value.to_f
          when Symbol
            parse(SYMBOL_MAP.fetch(value), bpm: bpm, time_signature: time_signature)
          when /\A(\d+)n\z/
            beats = 4.0 / Regexp.last_match(1).to_f
            beats * beat_duration(bpm)
          when /\A(\d+)t\z/
            beats = (4.0 / Regexp.last_match(1).to_f) * (2.0 / 3.0)
            beats * beat_duration(bpm)
          when /\A(\d+)n\.\z/
            parse("#{Regexp.last_match(1)}n", bpm: bpm, time_signature: time_signature) * 1.5
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
          else
            Float(value)
          end
        rescue KeyError, ArgumentError
          raise ArgumentError, "Unknown time format: #{value}"
        end

        private

        def beat_duration(bpm)
          60.0 / bpm.to_f
        end
      end
    end
  end
end
