# frozen_string_literal: true

module Deftones
  module Component
    class Solo < Core::AudioNode
      @instances = []

      class << self
        attr_reader :instances
      end

      attr_accessor :muted

      def initialize(solo: false, muted: false, context: Deftones.context)
        super(context: context)
        @solo = solo
        @muted = muted
        self.class.instances << self
      end

      def solo?
        @solo
      end

      def solo=(value)
        @solo = !!value
      end

      def mute
        @muted
      end

      def mute=(value)
        @muted = !!value
      end

      def dispose
        self.class.instances.delete(self)
        super
      end

      def process(input_buffer, num_frames, _start_frame, _cache)
        return Array.new(num_frames, 0.0) if @muted
        return input_buffer unless self.class.instances.any?(&:solo?)

        @solo ? input_buffer : Array.new(num_frames, 0.0)
      end

      alias mute? mute
    end
  end
end
