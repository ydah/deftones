# frozen_string_literal: true

module Deftones
  module Instrument
    class Sampler < Core::Instrument
      def initialize(samples:, max_voices: 8, context: Deftones.context)
        super(context: context)
        @samples = samples.transform_keys(&:to_s)
        @max_voices = max_voices
        @voices = []
      end

      def play(notes, duration: "8n", at: nil, velocity: 1.0)
        Array(notes).each do |note|
          trigger_attack(note, at, velocity)
          trigger_release(note, resolve_time(at) + Deftones::Music::Time.parse(duration))
        end
        self
      end

      def trigger_attack(note, time = nil, velocity = 1.0)
        buffer_note, buffer = closest_sample(note)
        playback_rate = Deftones::Music::Note.to_frequency(note) / Deftones::Music::Note.to_frequency(buffer_note)
        player = Source::Player.new(buffer: buffer, playback_rate: playback_rate, context: context)
        gain = Core::Gain.new(gain: velocity, context: context)
        player >> gain >> @output
        player.start(resolve_time(time))
        @voices << { note: note, player: player }
        @voices.shift if @voices.length > @max_voices
        self
      end

      def trigger_release(note, time = nil)
        voice = @voices.find { |entry| entry[:note] == note }
        voice&.fetch(:player)&.stop(resolve_time(time))
        self
      end

      private

      def closest_sample(note)
        target_midi = Deftones::Music::Note.to_midi(note)
        @samples.min_by do |sample_note, _|
          (Deftones::Music::Note.to_midi(sample_note) - target_midi).abs
        end
      end

      def resolve_time(time)
        return context.current_time if time.nil?

        Deftones::Music::Time.parse(time)
      end
    end
  end
end
