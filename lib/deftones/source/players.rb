# frozen_string_literal: true

module Deftones
  module Source
    class Players
      include Enumerable

      attr_accessor :mute

      def initialize(buffers = {}, context: Deftones.context)
        @context = context
        @players = {}
        @mute = false
        @disposed = false
        source_buffers = buffers.is_a?(IO::Buffers) ? buffers : IO::Buffers.new(buffers)
        source_buffers.each { |name, buffer| add(name, buffer) }
      end

      def add(name, buffer)
        player = Player.new(buffer: buffer, context: @context)
        @players[name.to_sym] = player
        player
      end

      def [](name)
        get(name)
      end

      def get(name)
        @players[name.to_sym]
      end

      def player(name)
        get(name)
      end

      def has?(name)
        @players.key?(name.to_sym)
      end

      def names
        @players.keys
      end

      def loaded?
        !@disposed
      end

      def loaded
        loaded?
      end

      def stop_all(time = nil)
        @players.each_value { |player| player.stop(time) }
        self
      end

      def state(name = nil, time: @context.current_time)
        return get(name)&.state(time) if name

        @players.transform_values { |player| player.state(time) }
      end

      def dispose
        @players.each_value(&:dispose)
        @players.clear
        @disposed = true
        self
      end

      def each(&block)
        return enum_for(:each) unless block

        @players.each_value(&block)
      end

      alias stopAll stop_all
      alias mute? mute
    end
  end
end
