# frozen_string_literal: true

module Deftones
  module Event
    class Loop
      include CallbackBehavior

      attr_reader :interval, :iterations

      def initialize(interval:, iterations: nil, transport: Deftones.transport,
                     probability: 1.0, humanize: false, mute: false, playback_rate: 1.0, &callback)
        @interval = interval
        @iterations = iterations
        @transport = transport
        @callback = callback
        @event_id = nil
        initialize_callback_behavior(
          probability: probability,
          humanize: humanize,
          mute: mute,
          playback_rate: playback_rate
        )
      end

      def start(time = 0)
        count = 0
        scaled_interval = callback_interval(@interval)
        duration = @iterations ? (scaled_interval * (@iterations - 1)) : nil
        @event_id = @transport.schedule_repeat(scaled_interval, start_time: time, duration: duration) do |scheduled_time|
          @callback.call(humanized_time(scheduled_time)) if callback_permitted?
          count += 1
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
    end
  end
end
