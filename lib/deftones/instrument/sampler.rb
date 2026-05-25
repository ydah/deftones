# frozen_string_literal: true

module Deftones
  module Instrument
    class Sampler < Core::Instrument
      attr_reader :choke_group, :release, :samples, :voices
      attr_reader :one_shot

      def initialize(samples:, max_voices: 8, release: 0.0, one_shot: false, choke_group: nil,
                     context: Deftones.context)
        super(context: context)
        @samples = samples.transform_keys(&:to_s)
        @max_voices = max_voices
        @release = release.to_f
        @one_shot = !!one_shot
        @choke_group = choke_group
        @voices = []
        rebuild_root_note_cache
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
        scheduled_time = resolve_time(time)
        choke_matching_voices(scheduled_time)
        playback_rate = Deftones::Music::Note.to_frequency(note) / Deftones::Music::Note.to_frequency(buffer_note)
        player = Source::Player.new(buffer: buffer, playback_rate: playback_rate, fade_out: @release, context: context)
        gain = Core::Gain.new(gain: velocity, context: context)
        player >> gain >> @output
        player.start(scheduled_time)
        @voices << { note: note, player: player, choke_group: @choke_group }
        steal_oldest_voice(scheduled_time) if @voices.length > @max_voices
        self
      end

      def trigger_release(note, time = nil)
        return self if @one_shot

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
        rebuild_root_note_cache
        self
      end

      def get(note)
        @samples[note.to_s]
      end

      def has?(note)
        @samples.key?(note.to_s)
      end

      def release_all(time = nil, force: false)
        scheduled_time = resolve_time(time)
        return self if @one_shot && !force

        @voices.each { |voice| voice[:player].stop(scheduled_time) }
        self
      end

      def loaded?
        !disposed?
      end

      def dispose
        release_all(context.current_time, force: true)
        @voices.clear
        super
      end

      alias loaded loaded?
      alias triggerAttackRelease trigger_attack_release
      alias releaseAll release_all
      alias oneShot one_shot

      private

      def closest_sample(note)
        raise ArgumentError, "Sampler requires at least one sample" if @samples.empty?

        target_midi = Deftones::Music::Note.to_midi(note)
        @samples.min_by do |sample_note, _|
          (@root_note_cache.fetch(sample_note) - target_midi).abs
        end
      end

      def steal_oldest_voice(time)
        stolen = @voices.shift
        return unless stolen

        player = stolen[:player]
        player.stop(time)
        player.dispose
      end

      def choke_matching_voices(time)
        return unless @choke_group

        @voices.delete_if do |voice|
          next false unless voice[:choke_group] == @choke_group

          voice[:player].stop(time)
          voice[:player].dispose
          true
        end
      end

      def rebuild_root_note_cache
        @root_note_cache = @samples.each_key.to_h do |sample_note|
          [sample_note, Deftones::Music::Note.to_midi(sample_note)]
        end
      end

      def resolve_time(time)
        return context.current_time if time.nil?

        Deftones::Music::Time.parse(time)
      end
    end
  end
end
