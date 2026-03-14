# frozen_string_literal: true

module Deftones
  module Event
    class Pattern
      PATTERNS = %i[up down up_down random].freeze

      def initialize(values:, pattern: :up, interval: "4n", transport: Deftones.transport, &callback)
        @values = values
        @pattern = normalize_pattern(pattern)
        @interval = interval
        @transport = transport
        @callback = callback
        @event_id = nil
        @index = 0
        @direction = 1
      end

      def start(time = 0)
        @event_id = @transport.schedule_repeat(@interval, start_time: time) do |scheduled_time|
          @callback.call(scheduled_time, next_value)
        end
        self
      end

      def stop(_time = nil)
        @transport.cancel(event_id: @event_id) if @event_id
        @event_id = nil
        self
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
