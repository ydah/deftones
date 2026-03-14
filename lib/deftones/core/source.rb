# frozen_string_literal: true

module Deftones
  module Core
    class Source < AudioNode
      def initialize(context: Deftones.context)
        super(context: context)
        @start_time = 0.0
        @stop_time = nil
      end

      def start(time = nil)
        @start_time = resolve_time(time)
        @stop_time = nil if @stop_time && @stop_time <= @start_time
        self
      end

      def stop(time = nil)
        @stop_time = resolve_time(time)
        self
      end

      def active_at?(time)
        return false if time < @start_time
        return true if @stop_time.nil?

        time < @stop_time
      end

      private

      def resolve_time(time)
        return context.current_time if time.nil?

        Deftones::Music::Time.parse(time)
      end
    end
  end
end
