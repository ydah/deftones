# frozen_string_literal: true

module Deftones
  module IO
    class Buffers
      include Enumerable

      def initialize(buffers = {})
        @buffers = {}
        merge(buffers)
      end

      def add(name, buffer)
        @buffers[key_for(name)] = normalize_buffer(buffer)
        self
      end

      def [](name)
        @buffers[key_for(name)]
      end

      def fetch(name)
        @buffers.fetch(key_for(name))
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
