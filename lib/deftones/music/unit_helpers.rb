# frozen_string_literal: true

module Deftones
  module Music
    module UnitHelpers
      NOTATION_CANDIDATES = %w[1m 1n 2n. 2n 4n. 4n 8n. 8n 8t 16n. 16n 16t 32n 64n 128n].freeze

      class << self
        def closest_notation(seconds, transport:)
          NOTATION_CANDIDATES.min_by do |notation|
            duration = Time.parse(notation, bpm: transport.bpm, time_signature: transport.time_signature, ppq: transport.ppq)
            (duration - seconds).abs
          end
        end

        def quantize_seconds(seconds, subdivision, transport:, percent: 1.0)
          quantum = Time.parse(subdivision, bpm: transport.bpm, time_signature: transport.time_signature, ppq: transport.ppq)
          return seconds unless quantum.positive?

          target = (seconds / quantum).round * quantum
          seconds + ((target - seconds) * percent.to_f.clamp(0.0, 1.0))
        end

        def samples_for_seconds(seconds, sample_rate)
          (seconds * sample_rate.to_f).round
        end
      end
    end
  end
end
