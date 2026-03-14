# frozen_string_literal: true

module Deftones
  module Event
    class ToneEvent
      attr_accessor :loop, :loop_start, :loop_end, :probability

      def initialize(transport: Deftones.transport, probability: 1.0, loop: false,
                     loop_start: 0.0, loop_end: nil, &callback)
        @transport = transport
        @callback = callback
        @probability = probability.to_f
        @loop = loop
        @loop_start = loop_start
        @loop_end = loop_end
        @event_id = nil
      end

      def start(time = 0)
        start_time = resolve_time(time)

        @event_id =
          if @loop && @loop_end
            interval = resolve_time(@loop_end) - resolve_time(@loop_start)
            @transport.schedule_repeat(interval, start_time: start_time + resolve_time(@loop_start)) do |scheduled_time|
              @callback.call(scheduled_time) if rand <= @probability
            end
          else
            @transport.schedule(start_time) do |scheduled_time|
              @callback.call(scheduled_time) if rand <= @probability
            end
          end
        self
      end

      def stop(_time = nil)
        cancel
      end

      def cancel
        @transport.cancel(event_id: @event_id) if @event_id
        @event_id = nil
        self
      end

      private

      def resolve_time(value)
        Deftones::Music::Time.parse(value)
      end
    end
  end
end
