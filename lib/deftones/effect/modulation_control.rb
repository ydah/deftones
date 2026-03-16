# frozen_string_literal: true

module Deftones
  module Effects
    module ModulationControl
      def start(time = nil)
        return schedule_modulation_event(:start, time) if synced?

        @modulation_start_time = resolve_modulation_time(time)
        @modulation_stop_time = nil if @modulation_stop_time && @modulation_stop_time <= @modulation_start_time
        self
      end

      def stop(time = nil)
        return schedule_modulation_event(:stop, time) if synced?

        @modulation_stop_time = resolve_modulation_time(time)
        self
      end

      def restart(time = nil)
        stop(time)
        start(time)
      end

      def cancel_stop
        clear_modulation_event(:stop)
        @modulation_stop_time = nil
        self
      end

      def state(time = context.current_time)
        modulation_active_at?(resolve_modulation_time(time)) ? :started : :stopped
      end

      def sync
        @modulation_synced = true
        self
      end

      def unsync
        @modulation_synced = false
        clear_modulation_event(:start)
        clear_modulation_event(:stop)
        self
      end

      def synced?
        !!@modulation_synced
      end

      def dispose
        unsync
        super
      end

      alias cancelStop cancel_stop

      private

      def initialize_modulation_control
        @modulation_start_time = 0.0
        @modulation_stop_time = nil
        @modulation_synced = false
        @modulation_transport_event_ids = {}
      end

      def modulation_phase_for(current_time)
        return nil unless modulation_active_at?(current_time)

        current_phase = @phase
        @phase = (@phase + (modulation_frequency / context.sample_rate)) % 1.0
        current_phase
      end

      def modulation_frequency
        @frequency.to_f
      end

      def modulation_active_at?(time)
        time >= @modulation_start_time && (@modulation_stop_time.nil? || time < @modulation_stop_time)
      end

      def resolve_modulation_time(time)
        return context.current_time if time.nil?

        Deftones::Music::Time.parse(time)
      end

      def resolve_modulation_transport_time(time)
        return Deftones.transport.seconds if time.nil?

        time
      end

      def schedule_modulation_event(kind, time)
        clear_modulation_event(kind)
        @modulation_transport_event_ids[kind] = Deftones.transport.schedule(resolve_modulation_transport_time(time)) do |scheduled_time|
          if kind == :start
            @modulation_start_time = scheduled_time
            @modulation_stop_time = nil if @modulation_stop_time && @modulation_stop_time <= @modulation_start_time
          else
            @modulation_stop_time = scheduled_time
          end
        end
        self
      end

      def clear_modulation_event(kind)
        event_id = @modulation_transport_event_ids.delete(kind)
        return self unless event_id

        Deftones.transport.clear(event_id)
        self
      end
    end
  end
end
