# frozen_string_literal: true

module Deftones
  module Instrument
    class MembraneSynth < Core::Instrument
      attr_reader :oscillator, :envelope

      def initialize(pitch_decay: 0.05, octaves: 4.0, attack: 0.001, decay: 0.2,
                     sustain: 0.0, release: 0.15, context: Deftones.context, &block)
        super(context: context)
        @pitch_decay = pitch_decay.to_f
        @octaves = octaves.to_f
        @oscillator = Source::Oscillator.new(type: :sine, context: context)
        @envelope = Component::AmplitudeEnvelope.new(
          attack: attack,
          decay: decay,
          sustain: sustain,
          release: release,
          context: context
        )
        @oscillator.start(0.0)
        @oscillator >> @envelope >> @output
        block&.call(self)
      end

      def play(note, duration: "8n", at: nil, velocity: 1.0)
        trigger_attack_release(note, duration, at, velocity)
      end

      def trigger_attack(note, time = nil, velocity = 1.0)
        scheduled_time = resolve_time(time)
        base_frequency = Deftones::Music::Note.to_frequency(note)
        @oscillator.frequency.set_value_at_time(base_frequency * (2.0**@octaves), scheduled_time)
        @oscillator.frequency.exponential_ramp_to(base_frequency, @pitch_decay)
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

      def resolve_time(time)
        return context.current_time if time.nil?

        Deftones::Music::Time.parse(time)
      end
    end
  end
end
