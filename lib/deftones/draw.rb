# frozen_string_literal: true

require "forwardable"

module Deftones
  class Draw
    class << self
      extend Forwardable

      def_delegators :instance, :schedule, :cancel, :dispose, :prepare_render, :advance_to

      def instance
        @instance ||= new
      end

      def reset!
        @instance = nil
        self
      end
    end

    def initialize
      @timeline = {}
      @next_id = 0
    end

    def schedule(callback_or_time = nil, maybe_time = nil, &block)
      callback, time = resolve_schedule_arguments(callback_or_time, maybe_time, block)
      event_id = @next_id
      @timeline[event_id] = { time: resolve_time(time), callback: callback }
      @next_id += 1
      event_id
    end

    def cancel(after_time = 0, event_id: nil)
      if event_id.nil? && after_time.is_a?(Integer) && @timeline.key?(after_time)
        return @timeline.delete(after_time)
      end

      return @timeline.delete(event_id) if event_id

      threshold = resolve_time(after_time)
      @timeline.delete_if { |_id, event| event[:time] >= threshold }
      self
    end

    def dispose
      @timeline.clear
      @next_id = 0
      self
    end

    def prepare_render(duration)
      flush_until(duration)
      self
    end

    def advance_to(time)
      flush_until(time)
      self
    end

    private

    def resolve_schedule_arguments(callback_or_time, maybe_time, block)
      if callback_or_time.respond_to?(:call)
        [callback_or_time, maybe_time]
      else
        [block, callback_or_time]
      end.tap do |callback, _time|
        raise ArgumentError, "callback is required" unless callback
      end
    end

    def resolve_time(value)
      Deftones::Music::Time.parse(value || 0)
    end

    def due_events(limit)
      events = @timeline.values.select { |event| event[:time] <= limit }
      events.sort_by { |event| event[:time] }
    end

    def flush_until(time)
      limit = resolve_time(time)
      due_events(limit).each do |event|
        invoke(event[:callback], event[:time])
      end
      @timeline.delete_if { |_id, event| event[:time] <= limit }
    end

    def invoke(callback, time)
      callback.arity.zero? ? callback.call : callback.call(time)
    end
  end
end
