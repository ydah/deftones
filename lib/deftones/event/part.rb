# frozen_string_literal: true

module Deftones
  module Event
    class Part
      def initialize(events:, transport: Deftones.transport, &callback)
        @events = events
        @transport = transport
        @callback = callback
        @event_ids = []
      end

      def start(time = 0)
        offset = Deftones::Music::Time.parse(time)
        @event_ids = @events.map do |event|
          event_time = offset + Deftones::Music::Time.parse(event.fetch(:time, 0))
          @transport.schedule(event_time) do |scheduled_time|
            @callback.call(scheduled_time, event)
          end
        end
        self
      end

      def stop(_time = nil)
        @event_ids.each { |event_id| @transport.cancel(event_id: event_id) }
        @event_ids.clear
        self
      end
    end
  end
end
