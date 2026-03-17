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

      def multichannel_process?
        true
      end

      def process(input_block, num_frames, _start_frame, _cache)
        return Core::AudioBlock.silent(num_frames, input_block.channels) if @muted
        return input_block.dup unless self.class.instances.any?(&:solo?)

        @solo ? input_block.dup : Core::AudioBlock.silent(num_frames, input_block.channels)
      end

      alias mute? mute
    end
  end
end
