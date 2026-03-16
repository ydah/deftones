# frozen_string_literal: true

module Deftones
  module Core
    class Emitter
      def initialize
        @listeners = Hash.new { |hash, key| hash[key] = [] }
      end

      def on(event_name, &block)
        raise ArgumentError, "block is required" unless block

        @listeners[event_name.to_sym] << block
        self
      end

      def once(event_name, &block)
        raise ArgumentError, "block is required" unless block

        wrapper = nil
        wrapper = proc do |*arguments|
          off(event_name, wrapper)
          block.call(*arguments)
        end
        on(event_name, &wrapper)
      end

      def off(event_name, listener = nil)
        key = event_name.to_sym
        return @listeners.delete(key) unless listener

        @listeners[key].delete(listener)
        self
      end

      def emit(event_name, *arguments)
        @listeners[event_name.to_sym].dup.each { |listener| listener.call(*arguments) }
        self
      end

      def listeners(event_name)
        @listeners[event_name.to_sym].dup
      end

      def dispose
        @listeners.clear
        self
      end
    end
  end
end
