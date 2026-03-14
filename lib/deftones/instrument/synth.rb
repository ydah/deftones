# frozen_string_literal: true

module Deftones
  module Instrument
    class Synth < Core::Instrument
      attr_reader :oscillator, :envelope

      def initialize(type: :triangle, attack: 0.005, decay: 0.1, sustain: 0.3, release: 1.0,
                     context: Deftones.context, &block)
        super(context: context)
        @oscillator = Source::Oscillator.new(type: type, context: context)
        @envelope = Component::AmplitudeEnvelope.new(
          attack: attack,
          decay: decay,
          sustain: sustain,
          release: release,
          context: context
        )
        @oscillator >> @envelope >> @output
        block&.call(self)
      end

      def play(note, duration: "8n", at: nil, velocity: 1.0)
        trigger_attack_release(note, duration, at, velocity)
      end

      def trigger_attack(note, time = nil, velocity = 1.0)
        scheduled_time = resolve_time(time)
        @oscillator.frequency.set_value_at_time(note, scheduled_time)
        @oscillator.start(scheduled_time)
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

      def active?
        @envelope.active?
      end

      private

      def resolve_time(time)
        return context.current_time if time.nil?

        Deftones::Music::Time.parse(time)
      end
    end
  end
end
