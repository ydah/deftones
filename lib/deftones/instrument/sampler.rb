# frozen_string_literal: true

module Deftones
  module Instrument
    class Sampler < Core::Instrument
      attr_reader :samples, :voices

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

      def trigger_attack_release(note, duration, time = nil, velocity = 1.0)
        scheduled_time = resolve_time(time)
        trigger_attack(note, scheduled_time, velocity)
        trigger_release(note, scheduled_time + Deftones::Music::Time.parse(duration))
        self
      end

      def add(note, buffer)
        @samples[note.to_s] = buffer.is_a?(Deftones::IO::Buffer) ? buffer : Deftones::IO::Buffer.load(buffer)
        self
      end

      def get(note)
        @samples[note.to_s]
      end

      def has?(note)
        @samples.key?(note.to_s)
      end

      def release_all(time = nil)
        scheduled_time = resolve_time(time)
        @voices.each { |voice| voice[:player].stop(scheduled_time) }
        self
      end

      def loaded?
        true
      end

      def dispose
        release_all(context.current_time)
        @voices.clear
        super
      end

      alias loaded loaded?
      alias triggerAttackRelease trigger_attack_release
      alias releaseAll release_all

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
