# frozen_string_literal: true

module Deftones
  module Instrument
    class MonoSynth < Core::Instrument
      attr_reader :oscillator, :filter, :envelope, :filter_envelope

      def initialize(type: :sawtooth, filter_type: :lowpass, filter_frequency: 1_200.0, filter_q: 0.8,
                     filter_octaves: 2.0, attack: 0.01, decay: 0.1, sustain: 0.4, release: 0.5,
                     context: Deftones.context, &block)
        super(context: context)
        @oscillator = Source::OmniOscillator.new(type: type, context: context)
        @filter = Component::Filter.new(
          type: filter_type,
          frequency: filter_frequency,
          q: filter_q,
          context: context
        )
        @envelope = Component::AmplitudeEnvelope.new(
          attack: attack,
          decay: decay,
          sustain: sustain,
          release: release,
          context: context
        )
        @filter_envelope = Component::FrequencyEnvelope.new(
          base_frequency: filter_frequency,
          octaves: filter_octaves,
          attack: attack,
          decay: decay,
          sustain: sustain,
          release: release,
          context: context
        )
        @oscillator.start(0.0)
        @oscillator >> @filter >> @envelope >> @output
        block&.call(self)
      end

      def play(note, duration: "8n", at: nil, velocity: 1.0)
        trigger_attack_release(note, duration, at, velocity)
      end

      def trigger_attack(note, time = nil, velocity = 1.0)
        scheduled_time = resolve_time(time)
        frequency = Deftones::Music::Note.to_frequency(note)
        @oscillator.frequency.set_value_at_time(frequency, scheduled_time)
        shape_filter(scheduled_time, velocity)
        @envelope.trigger_attack(scheduled_time, velocity)
        self
      end

      def trigger_release(time = nil)
        scheduled_time = resolve_time(time)
        @filter.frequency.linear_ramp_to(@filter_envelope.base_frequency, @envelope.release)
        @envelope.trigger_release(scheduled_time)
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

      def shape_filter(time, velocity)
        peak = @filter_envelope.base_frequency * (2.0**(@filter_envelope.octaves * velocity))
        sustain_level = @filter_envelope.base_frequency * (1.0 + (@filter_envelope.sustain * velocity))
        @filter.frequency.set_value_at_time(@filter_envelope.base_frequency, time)
        @filter.frequency.linear_ramp_to(peak, @filter_envelope.attack)
        @filter.frequency.linear_ramp_to(sustain_level, @filter_envelope.decay)
      end

      def resolve_time(time)
        return context.current_time if time.nil?

        Deftones::Music::Time.parse(time)
      end
    end
  end
end
