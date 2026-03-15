# frozen_string_literal: true

module Deftones
  module IO
    class Buffers
      include Enumerable

      def initialize(buffers = {})
        @buffers = {}
        @disposed = false
        merge(buffers)
      end

      def add(name, buffer)
        @buffers[key_for(name)] = normalize_buffer(buffer)
        self
      end

      def get(name)
        self[name]
      end

      def [](name)
        @buffers[key_for(name)]
      end

      def fetch(name)
        @buffers.fetch(key_for(name))
      end

      def has?(name)
        @buffers.key?(key_for(name))
      end

      def loaded?
        !@disposed
      end

      def each(&block)
        return enum_for(:each) unless block

        @buffers.each(&block)
      end

      def keys
        @buffers.keys
      end

      def to_h
        @buffers.dup
      end

      def merge(buffers)
        buffers.each { |name, buffer| add(name, buffer) }
        self
      end

      def dispose
        @buffers.clear
        @disposed = true
        self
      end

      alias loaded loaded?

      private

      def key_for(name)
        name.to_sym
      end

      def normalize_buffer(buffer)
        buffer.is_a?(Buffer) ? buffer : Buffer.load(buffer)
      end
    end
  end
end
