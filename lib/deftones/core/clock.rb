# frozen_string_literal: true

module Deftones
  module Core
    class Clock < Emitter
      attr_reader :context, :frequency, :state

      def initialize(frequency: 1.0, context: Deftones.context, &block)
        super()
        @context = context
        @frequency = Signal.new(value: frequency, units: :frequency, context: context)
        @state = :stopped
        @start_time = 0.0
        @offset_ticks = 0.0
        on(:tick, &block) if block
      end

      def start(time = nil, offset: nil)
        @start_time = resolve_time(time)
        @offset_ticks = offset.to_f if offset
        @state = :started
        self
      end

      def stop(time = nil)
        @offset_ticks = ticks_at(resolve_time(time))
        @start_time = resolve_time(time)
        @state = :stopped
        self
      end

      def pause(time = nil)
        @offset_ticks = ticks_at(resolve_time(time))
        @start_time = resolve_time(time)
        @state = :paused
        self
      end

      def ticks(time = context.current_time)
        ticks_at(resolve_time(time))
      end

      def seconds(time = context.current_time)
        ticks(time) / current_frequency
      end

      def next_tick_time(time = context.current_time)
        tick_duration = 1.0 / current_frequency
        current_ticks = ticks(time)
        next_tick = current_ticks.floor + 1
        resolve_time(time) + ((next_tick - current_ticks) * tick_duration)
      end

      def get_ticks_at_time(time)
        ticks(time)
      end

      def emit_ticks_until(time)
        return self unless state == :started

        current_time = resolve_time(time)
        emitted_ticks = (@last_emitted_tick || @offset_ticks.floor) + 1
        while emitted_ticks <= ticks_at(current_time).floor
          emit(:tick, emitted_ticks)
          emitted_ticks += 1
        end
        @last_emitted_tick = emitted_ticks - 1
        self
      end

      alias getTicksAtTime get_ticks_at_time
      alias nextTickTime next_tick_time

      private

      def resolve_time(value)
        value.nil? ? context.current_time : Deftones::Music::Time.parse(value)
      end

      def ticks_at(time)
        return @offset_ticks unless state == :started

        @offset_ticks + ([time - @start_time, 0.0].max * current_frequency)
      end

      def current_frequency
        [frequency.value.to_f, 1.0e-6].max
      end
    end
  end
end
