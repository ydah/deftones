# frozen_string_literal: true

module Deftones
  module Event
    class Part
      include CallbackBehavior

      def initialize(events:, transport: Deftones.transport,
                     probability: 1.0, humanize: false, mute: false, playback_rate: 1.0, &callback)
        @events = events
        @transport = transport
        @callback = callback
        @event_ids = []
        initialize_callback_behavior(
          probability: probability,
          humanize: humanize,
          mute: mute,
          playback_rate: playback_rate
        )
      end

      def start(time = 0)
        offset = callback_time(time)
        @event_ids = @events.map do |event|
          event_time = offset + callback_interval(event.fetch(:time, 0))
          @transport.schedule(event_time) do |scheduled_time|
            @callback.call(humanized_time(scheduled_time), event) if callback_permitted?
          end
        end
        mark_started
        self
      end

      def stop(_time = nil)
        cancel
      end

      def cancel
        @event_ids.each { |event_id| @transport.cancel(event_id: event_id) }
        @event_ids.clear
        mark_stopped
        self
      end

      def dispose
        cancel
        self
      end
    end
  end
end
