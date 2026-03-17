# frozen_string_literal: true

module Deftones
  module Source
    class Players
      include Enumerable

      class VolumeProxy
        attr_reader :players
        attr_accessor :value

        def initialize(players, value: 0.0)
          @players = players
          @value = value.to_f
        end

        def value=(new_value)
          @value = new_value.to_f
          players.send(:apply_controls!)
        end

        def ramp_to(target_value, _duration = nil)
          self.value = target_value
          self
        end

        alias linear_ramp_to ramp_to
        alias exponential_ramp_to ramp_to
      end

      attr_reader :volume

      def initialize(buffers = {}, context: Deftones.context)
        @context = context
        @players = {}
        @mute = false
        @volume = VolumeProxy.new(self)
        @disposed = false
        source_buffers = buffers.is_a?(IO::Buffers) ? buffers : IO::Buffers.new(buffers)
        source_buffers.each { |name, buffer| add(name, buffer) }
      end

      def add(name, buffer)
        player = Player.new(buffer: buffer, context: @context)
        player.volume.value = @volume.value
        player.mute = @mute
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

      def mute
        @mute
      end

      def mute=(value)
        @mute = !!value
        apply_controls!
      end

      def mute?
        @mute
      end

      def volume=(value)
        @volume.value = value
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

      private

      def apply_controls!
        @players.each_value do |player|
          player.volume.value = @volume.value
          player.mute = @mute
        end
        self
      end
    end
  end
end
