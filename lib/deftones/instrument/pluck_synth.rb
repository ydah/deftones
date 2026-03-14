# frozen_string_literal: true

module Deftones
  module Instrument
    class PluckSynth < Core::Instrument
      attr_reader :resonator

      def initialize(decay: 0.995, damping: 0.5, context: Deftones.context, &block)
        super(context: context)
        @resonator = Source::KarplusStrong.new(decay: decay, damping: damping, context: context)
        @resonator >> @output
        block&.call(self)
      end

      def play(note, duration: "8n", at: nil, velocity: 1.0)
        trigger_attack_release(note, duration, at, velocity)
      end

      def trigger_attack(note, time = nil, velocity = 1.0)
        @resonator.trigger(note, resolve_time(time), velocity)
        self
      end

      def trigger_release(_time = nil)
        self
      end

      def trigger_attack_release(note, _duration, time = nil, velocity = 1.0)
        trigger_attack(note, resolve_time(time), velocity)
      end

      private

      def resolve_time(time)
        return context.current_time if time.nil?

        Deftones::Music::Time.parse(time)
      end
    end
  end
end
