# frozen_string_literal: true

module Deftones
  module Event
    class Pattern
      include CallbackBehavior

      PATTERNS = %i[up down up_down down_up alternate_up alternate_down random random_walk].freeze
      PATTERN_ALIASES = {
        upDown: :up_down,
        downUp: :down_up,
        alternateUp: :alternate_up,
        alternateDown: :alternate_down,
        randomWalk: :random_walk
      }.freeze

      def initialize(values:, pattern: :up, interval: "4n", transport: Deftones.transport,
                     probability: 1.0, humanize: false, mute: false, playback_rate: 1.0,
                     seed: nil, rng: nil, &callback)
        raise ArgumentError, "callback is required" unless callback

        @values = Array(values)
        raise ArgumentError, "Pattern values must not be empty" if @values.empty?

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
          playback_rate: playback_rate,
          seed: seed,
          rng: rng
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
        when :down_up
          descending_bounce_value
        when :alternate_up
          alternate_value(:up)
        when :alternate_down
          alternate_value(:down)
        when :random
          @values[@rng.rand(@values.length)]
        when :random_walk
          random_walk_value
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

      def descending_bounce_value
        value = @values.reverse[@index]
        @direction = -1 if @index >= @values.length - 1
        @direction = 1 if @index <= 0
        @index += @direction
        value
      end

      def alternate_value(start_direction)
        cycle = @index / @values.length
        offset = @index % @values.length
        @index += 1
        descending = start_direction == :down ? cycle.even? : cycle.odd?
        descending ? @values.reverse[offset] : @values[offset]
      end

      def random_walk_value
        value = @values[@index]
        @direction = [-1, 1][@rng.rand(2)]
        @index = (@index + @direction).clamp(0, @values.length - 1)
        value
      end

      def normalize_pattern(pattern)
        normalized = PATTERN_ALIASES.fetch(pattern.to_sym, pattern.to_sym)
        return normalized if PATTERNS.include?(normalized)

        raise ArgumentError, "Unsupported pattern: #{pattern}"
      end
    end
  end
end
