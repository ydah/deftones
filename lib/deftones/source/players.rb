# frozen_string_literal: true

module Deftones
  module Source
    class Players
      include Enumerable

      def initialize(buffers = {}, context: Deftones.context)
        @context = context
        @players = {}
        source_buffers = buffers.is_a?(IO::Buffers) ? buffers : IO::Buffers.new(buffers)
        source_buffers.each { |name, buffer| add(name, buffer) }
      end

      def add(name, buffer)
        @players[name.to_sym] = Player.new(buffer: buffer, context: @context)
      end

      def [](name)
        @players[name.to_sym]
      end

      def each(&block)
        return enum_for(:each) unless block

        @players.each_value(&block)
      end
    end
  end
end
