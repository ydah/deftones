# frozen_string_literal: true

module Deftones
  module Event
    class Part
      include CallbackBehavior

      def initialize(events:, transport: Deftones.transport,
                     probability: 1.0, humanize: false, mute: false, playback_rate: 1.0,
                     seed: nil, rng: nil, &callback)
        raise ArgumentError, "callback is required" unless callback

        @events = normalize_events(events)
        @transport = transport
        @callback = callback
        @event_ids = []
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

      private

      def normalize_events(events)
        Array(events).map do |event|
          next { time: event[0], value: event[1] } if event.is_a?(Array)

          event
        end
      end
    end
  end
end
