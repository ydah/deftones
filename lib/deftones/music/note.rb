# frozen_string_literal: true

module Deftones
  module Music
    class Note
      NOTE_NAMES = %w[C C# D D# E F F# G G# A A# B].freeze
      FLAT_MAP = {
        "Cb" => "B",
        "Db" => "C#",
        "Eb" => "D#",
        "Fb" => "E",
        "Gb" => "F#",
        "Ab" => "G#",
        "Bb" => "A#"
      }.freeze

      class << self
        def to_frequency(note_name)
          midi_number = to_midi(note_name)
          440.0 * (2.0**((midi_number - 69) / 12.0))
        end

        def to_midi(note_name)
          name, octave = parse_note_name(note_name)
          NOTE_NAMES.index(name) + ((octave + 1) * 12)
        end

        def from_midi(midi_number)
          integer = midi_number.to_i
          octave = (integer / 12) - 1
          "#{NOTE_NAMES[integer % 12]}#{octave}"
        end

        def from_frequency(frequency)
          normalized_frequency = frequency.to_f
          raise ArgumentError, "Frequency must be positive" unless normalized_frequency.positive? && normalized_frequency.finite?

          midi_number = (12 * Math.log2(normalized_frequency / 440.0) + 69).round
          from_midi(midi_number)
        end

        private

        def parse_note_name(note_name)
          validate_accidentals!(note_name)
          match = note_name.to_s.match(/\A([A-Ga-g][#b]?)(-?\d+)\z/)
          raise ArgumentError, "Invalid note: #{note_name}" unless match

          normalized_name = normalize_name(match[1])
          raise ArgumentError, "Unsupported note name: #{note_name}" unless NOTE_NAMES.include?(normalized_name)

          [normalized_name, match[2].to_i]
        end

        def validate_accidentals!(note_name)
          return unless note_name.to_s.match?(/\A[A-Ga-g](?:##|bb)/)

          raise ArgumentError, "Double accidentals are unsupported: #{note_name}"
        end

        def normalize_name(token)
          canonical = token[0].upcase + token[1..]
          FLAT_MAP.fetch(canonical, canonical.upcase)
        end
      end
    end
  end
end
