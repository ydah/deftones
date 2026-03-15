# frozen_string_literal: true

module Deftones
  module Event
    class Pattern
      include CallbackBehavior

      PATTERNS = %i[up down up_down random].freeze

      def initialize(values:, pattern: :up, interval: "4n", transport: Deftones.transport,
                     probability: 1.0, humanize: false, mute: false, playback_rate: 1.0, &callback)
        @values = values
        @pattern = normalize_pattern(pattern)
        @interval = interval
        @transport = transport
        @callback = callback
        @event_id = nil
        @index = 0
        @direction = 1
        initialize_callback_behavior(
          probability: probability,
          humanize: humanize,
          mute: mute,
          playback_rate: playback_rate
        )
      end

      def start(time = 0)
        @event_id = @transport.schedule_repeat(callback_interval(@interval), start_time: time) do |scheduled_time|
          @callback.call(humanized_time(scheduled_time), next_value) if callback_permitted?
        end
        mark_started
        self
      end

      def stop(_time = nil)
        cancel
      end

      def cancel
        @transport.cancel(event_id: @event_id) if @event_id
        @event_id = nil
        mark_stopped
        self
      end

      def dispose
        cancel
      end

      private

      def next_value
        case @pattern
        when :up
          ordered_value
        when :down
          descending_value
        when :up_down
          bounce_value
        when :random
          @values.sample
        end
      end

      def ordered_value
        value = @values[@index % @values.length]
        @index += 1
        value
      end

      def descending_value
        value = @values.reverse[@index % @values.length]
        @index += 1
        value
      end

      def bounce_value
        value = @values[@index]
        @direction = -1 if @index >= @values.length - 1
        @direction = 1 if @index <= 0
        @index += @direction
        value
      end

      def normalize_pattern(pattern)
        normalized = pattern.to_sym
        return normalized if PATTERNS.include?(normalized)

        raise ArgumentError, "Unsupported pattern: #{pattern}"
      end
    end
  end
end
