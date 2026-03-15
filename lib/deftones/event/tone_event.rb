# frozen_string_literal: true

module Deftones
  module Event
    class ToneEvent
      include CallbackBehavior

      attr_accessor :loop, :loop_start, :loop_end, :probability

      def initialize(transport: Deftones.transport, probability: 1.0, loop: false,
                     loop_start: 0.0, loop_end: nil, humanize: false, mute: false, playback_rate: 1.0, &callback)
        @transport = transport
        @callback = callback
        @loop = loop
        @loop_start = loop_start
        @loop_end = loop_end
        @event_id = nil
        initialize_callback_behavior(
          probability: probability,
          humanize: humanize,
          mute: mute,
          playback_rate: playback_rate
        )
      end

      def start(time = 0)
        start_time = resolve_time(time)

        @event_id =
          if @loop && @loop_end
            interval = callback_interval(resolve_time(@loop_end) - resolve_time(@loop_start))
            @transport.schedule_repeat(interval, start_time: start_time + resolve_time(@loop_start)) do |scheduled_time|
              @callback.call(humanized_time(scheduled_time)) if callback_permitted?
            end
          else
            @transport.schedule(start_time) do |scheduled_time|
              @callback.call(humanized_time(scheduled_time)) if callback_permitted?
            end
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

      def resolve_time(value)
        Deftones::Music::Time.parse(value)
      end
    end
  end
end
