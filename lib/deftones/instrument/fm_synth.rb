# frozen_string_literal: true

module Deftones
  module Instrument
    class FMSynth < Core::Instrument
      attr_reader :oscillator, :envelope

      def initialize(harmonicity: 2.0, modulation_index: 6.0, attack: 0.01, decay: 0.1,
                     sustain: 0.4, release: 0.4, context: Deftones.context, &block)
        super(context: context)
        @oscillator = Source::FMOscillator.new(
          harmonicity: harmonicity,
          modulation_index: modulation_index,
          context: context
        )
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
        @oscillator.frequency.set_value_at_time(note, scheduled_time)
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
