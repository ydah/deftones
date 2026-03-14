# frozen_string_literal: true

module Deftones
  module Instrument
    class MetalSynth < Core::Instrument
      attr_reader :oscillator, :filter, :envelope

      def initialize(harmonicity: 5.0, modulation_index: 12.0, attack: 0.001, decay: 0.08,
                     sustain: 0.0, release: 0.06, context: Deftones.context, &block)
        super(context: context)
        @oscillator = Source::FMOscillator.new(
          harmonicity: harmonicity,
          modulation_index: modulation_index,
          context: context
        )
        @filter = Component::Filter.new(type: :highpass, frequency: 2_500.0, q: 0.9, context: context)
        @envelope = Component::AmplitudeEnvelope.new(
          attack: attack,
          decay: decay,
          sustain: sustain,
          release: release,
          context: context
        )
        @oscillator >> @filter >> @envelope >> @output
        block&.call(self)
      end

      def play(note, duration: "16n", at: nil, velocity: 1.0)
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

      private

      def resolve_time(time)
        return context.current_time if time.nil?

        Deftones::Music::Time.parse(time)
      end
    end
  end
end
