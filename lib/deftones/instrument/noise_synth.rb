# frozen_string_literal: true

module Deftones
  module Instrument
    class NoiseSynth < Core::Instrument
      attr_reader :noise, :filter, :envelope

      def initialize(type: :white, filter_type: :bandpass, filter_frequency: 1_500.0, attack: 0.001,
                     decay: 0.12, sustain: 0.0, release: 0.1, context: Deftones.context, &block)
        super(context: context)
        @noise = Source::Noise.new(type: type, context: context)
        @filter = Component::Filter.new(type: filter_type, frequency: filter_frequency, q: 0.8, context: context)
        @envelope = Component::AmplitudeEnvelope.new(
          attack: attack,
          decay: decay,
          sustain: sustain,
          release: release,
          context: context
        )
        @noise >> @filter >> @envelope >> @output
        block&.call(self)
      end

      def play(_note = nil, duration: "8n", at: nil, velocity: 1.0)
        trigger_attack_release(duration, at, velocity)
      end

      def trigger_attack(time = nil, velocity = 1.0)
        scheduled_time = resolve_time(time)
        @noise.start(scheduled_time)
        @envelope.trigger_attack(scheduled_time, velocity)
        self
      end

      def trigger_release(time = nil)
        @envelope.trigger_release(resolve_time(time))
        self
      end

      def trigger_attack_release(duration, time = nil, velocity = 1.0)
        scheduled_time = resolve_time(time)
        trigger_attack(scheduled_time, velocity)
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
