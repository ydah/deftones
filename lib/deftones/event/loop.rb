# frozen_string_literal: true

module Deftones
  module Event
    class Loop
      attr_reader :interval, :iterations

      def initialize(interval:, iterations: nil, transport: Deftones.transport, &callback)
        @interval = interval
        @iterations = iterations
        @transport = transport
        @callback = callback
        @event_id = nil
      end

      def start(time = 0)
        count = 0
        duration = @iterations ? (Deftones::Music::Time.parse(@interval) * (@iterations - 1)) : nil
        @event_id = @transport.schedule_repeat(@interval, start_time: time, duration: duration) do |scheduled_time|
          @callback.call(scheduled_time)
          count += 1
        end
        self
      end

      def stop(_time = nil)
        @transport.cancel(event_id: @event_id) if @event_id
        @event_id = nil
        self
      end
    end
  end
end
