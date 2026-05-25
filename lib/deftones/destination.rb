# frozen_string_literal: true

require "forwardable"

module Deftones
  class Destination
    class VolumeProxy
      attr_reader :destination
      attr_reader :value

      def initialize(destination, value: 0.0)
        @destination = destination
        @value = value.to_f
      end

      def value=(new_value)
        @value = new_value.to_f
        destination.apply_volume!
      end

      def ramp_to(target_value, duration = nil)
        return assign_immediately(target_value) if duration.nil?

        resolved_duration = Deftones::Music::Time.parse(duration)
        return assign_immediately(target_value) if resolved_duration <= 0.0

        @value = target_value.to_f
        destination.node.gain.linear_ramp_to_value_at_time(
          destination.mute? ? 0.0 : Deftones.db_to_gain(@value),
          destination.context.current_time + resolved_duration
        )
        self
      end

      def linear_ramp_to(target_value, duration = nil)
        ramp_to(target_value, duration)
      end

      def exponential_ramp_to(target_value, duration = nil)
        ramp_to(target_value, duration)
      end

      def set_value_at_time(target_value, _time)
        @value = target_value.to_f
        destination.node.gain.set_value_at_time(destination.mute? ? 0.0 : Deftones.db_to_gain(@value), _time)
        self
      end

      alias linearRampTo linear_ramp_to
      alias exponentialRampTo exponential_ramp_to
      alias setValueAtTime set_value_at_time

      private

      def assign_immediately(target_value)
        self.value = target_value
        self
      end
    end

    attr_reader :context, :mute, :volume

    class << self
      extend Forwardable

      def_delegators :node, :input, :output, :volume, :mute, :mute=, :mute?
      def_delegators :node, :sample_time, :block_time, :max_channel_count
      def_delegators :node, :connect, :disconnect, :chain, :fan, :apply_volume!
      def_delegators :node, :sampleTime, :blockTime, :maxChannelCount

      def node(context: Deftones.context)
        registry[context.object_id] ||= new(context: context)
      end

      def reset!
        @registry = {}
        self
      end

      private

      def registry
        @registry ||= {}
      end
    end

    def initialize(context:)
      @context = context
      @volume = VolumeProxy.new(self)
      @mute = false
      apply_volume!
    end

    def input
      node
    end

    def output
      node
    end

    def node
      context.output
    end

    def mute=(value)
      @mute = !!value
      apply_volume!
    end

    def mute?
      @mute
    end

    def name
      "Destination"
    end

    def sample_time
      1.0 / context.sample_rate
    end

    def block_time
      context.buffer_size.to_f / context.sample_rate
    end

    def max_channel_count
      context.channels
    end

    def connect(*arguments, **keywords)
      node.connect(*arguments, **keywords)
    end

    def disconnect(*arguments)
      node.disconnect(*arguments)
    end

    def chain(*nodes)
      node.chain(*nodes)
    end

    def fan(*nodes)
      node.fan(*nodes)
    end

    def apply_volume!
      node.gain.value = mute ? 0.0 : Deftones.db_to_gain(@volume.value)
      self
    end

    alias sampleTime sample_time
    alias blockTime block_time
    alias maxChannelCount max_channel_count
  end
end
