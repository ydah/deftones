# frozen_string_literal: true

module Deftones
  module Event
    module CallbackBehavior
      attr_accessor :humanize, :mute, :playback_rate, :probability
      attr_reader :state

      private

      def initialize_callback_behavior(probability: 1.0, humanize: false, mute: false, playback_rate: 1.0)
        @probability = probability.to_f
        @humanize = humanize
        @mute = !!mute
        @playback_rate = playback_rate.to_f
        @state = :stopped
      end

      def mark_started
        @state = :started
      end

      def mark_stopped
        @state = :stopped
      end

      def callback_interval(value)
        base = Deftones::Music::Time.parse(value)
        rate = @playback_rate.zero? ? 1.0 : @playback_rate.abs
        base / rate
      end

      def callback_time(value)
        Deftones::Music::Time.parse(value)
      end

      def callback_permitted?
        return false if @mute

        rand <= @probability
      end

      def humanized_time(time)
        return time unless @humanize

        amount = @humanize == true ? 0.01 : Deftones::Music::Time.parse(@humanize)
        time + (((rand * 2.0) - 1.0) * amount)
      end
    end
  end
end
