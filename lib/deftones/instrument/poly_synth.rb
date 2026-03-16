# frozen_string_literal: true

module Deftones
  module Instrument
    class PolySynth < Core::Instrument
      attr_reader :voice_pool

      def initialize(voice_class = Synth, voices: 8, context: Deftones.context, **voice_options)
        super(context: context)
        @voice_class = voice_class
        @voice_pool = Array.new(voices) { @voice_class.new(context: context, **voice_options) }
        @voice_pool.each { |voice| voice >> @output }
        @active_voices = {}
      end

      def play(notes, duration: "8n", at: nil, velocity: 1.0)
        scheduled_time = resolve_time(at)

        Array(notes).compact.each do |note|
          trigger_attack(note, scheduled_time, velocity)
        end

        release_time = scheduled_time + Deftones::Music::Time.parse(duration)
        Array(notes).compact.each do |note|
          trigger_release(note, release_time)
        end

        self
      end

      def trigger_attack(note, time = nil, velocity = 1.0)
        voice = allocate_voice(note)
        @active_voices.delete(note)
        @active_voices[note] = voice
        voice.trigger_attack(note, resolve_time(time), velocity)
        self
      end

      def trigger_release(note, time = nil)
        voice = @active_voices.delete(note)
        voice&.trigger_release(resolve_time(time))
        self
      end

      def set(**params)
        @voice_pool.each do |voice|
          params.each do |key, value|
            writer = :"#{key}="
            voice.public_send(writer, value) if voice.respond_to?(writer)
          end
        end
        self
      end

      def release_all(time = nil)
        scheduled_time = resolve_time(time)
        @active_voices.each_value { |voice| voice.trigger_release(scheduled_time) }
        @active_voices.clear
        self
      end

      def max_polyphony
        @voice_pool.length
      end

      def loaded?
        true
      end

      alias loaded loaded?
      alias releaseAll release_all

      def active?
        @voice_pool.any?(&:active?)
      end

      private

      def allocate_voice(note)
        return @active_voices[note] if @active_voices.key?(note)

        available_voice = @voice_pool.find { |voice| !@active_voices.value?(voice) }
        return available_voice if available_voice

        _, stolen_voice = @active_voices.shift
        stolen_voice
      end

      def resolve_time(time)
        return context.current_time if time.nil?

        Deftones::Music::Time.parse(time)
      end
    end
  end
end
