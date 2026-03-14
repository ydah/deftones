# frozen_string_literal: true

module Deftones
  module Instrument
    class DuoSynth < Core::Instrument
      attr_reader :voice_a, :voice_b, :envelope

      def initialize(type: :sawtooth, detune: 7.0, harmonicity: 1.5, attack: 0.01, decay: 0.12,
                     sustain: 0.45, release: 0.4, context: Deftones.context, &block)
        super(context: context)
        @voice_a = Source::OmniOscillator.new(type: type, context: context)
        @voice_b = Source::OmniOscillator.new(type: type, context: context)
        @detune = detune.to_f
        @harmonicity = harmonicity.to_f
        @envelope = Component::AmplitudeEnvelope.new(
          attack: attack,
          decay: decay,
          sustain: sustain,
          release: release,
          context: context
        )
        @voice_a >> @envelope
        @voice_b >> @envelope
        @envelope >> @output
        block&.call(self)
      end

      def play(note, duration: "8n", at: nil, velocity: 1.0)
        trigger_attack_release(note, duration, at, velocity)
      end

      def trigger_attack(note, time = nil, velocity = 1.0)
        scheduled_time = resolve_time(time)
        frequency = Deftones::Music::Note.to_frequency(note)
        @voice_a.frequency.set_value_at_time(frequency * detune_ratio(-@detune), scheduled_time)
        @voice_b.frequency.set_value_at_time((frequency * @harmonicity) * detune_ratio(@detune), scheduled_time)
        @voice_a.start(scheduled_time)
        @voice_b.start(scheduled_time)
        @envelope.trigger_attack(scheduled_time, velocity)
        self
      end

      def trigger_release(time = nil)
        @envelope.trigger_release(resolve_time(time))
        self
      end

      def trigger_attack_release(note, duration, time = nil, velocity = 1.0)
        scheduled_time = resolve_time(time)
        trigger_attack(note, scheduled_time, velocity)
        trigger_release(scheduled_time + Deftones::Music::Time.parse(duration))
        self
      end

      private

      def detune_ratio(cents)
        2.0**(cents.to_f / 1200.0)
      end

      def resolve_time(time)
        return context.current_time if time.nil?

        Deftones::Music::Time.parse(time)
      end
    end
  end
end
