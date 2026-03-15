# frozen_string_literal: true

module Deftones
  class Destination
    class VolumeProxy
      attr_reader :destination
      attr_accessor :value

      def initialize(destination, value: 0.0)
        @destination = destination
        @value = value.to_f
      end

      def value=(new_value)
        @value = new_value.to_f
        destination.apply_volume!
      end

      def ramp_to(target_value, _duration = nil)
        self.value = target_value
        self
      end

      alias linear_ramp_to ramp_to
      alias exponential_ramp_to ramp_to

      def set_value_at_time(target_value, _time)
        self.value = target_value
        self
      end
    end

    attr_reader :context, :volume
    attr_accessor :mute

    class << self
      def node(context: Deftones.context)
        registry[context.object_id] ||= new(context: context)
      end

      def reset!
        @registry = {}
        self
      end

      def method_missing(method_name, *arguments, &block)
        return super unless node.respond_to?(method_name)

        node.public_send(method_name, *arguments, &block)
      end

      def respond_to_missing?(method_name, include_private = false)
        node.respond_to?(method_name, include_private) || super
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
  end
end
