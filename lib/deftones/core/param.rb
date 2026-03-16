# frozen_string_literal: true

module Deftones
  module Core
    class Param < Signal
      attr_reader :lfo

      def initialize(**options)
        super
        @lfo = nil
      end

      def set_param(param)
        @param = param
        self
      end

      def connect(destination, output_index: 0, input_index: 0)
        super
        @param = destination if destination.respond_to?(:value=)
        self
      end

      def lfo=(source)
        @lfo = source
      end

      alias setParam set_param
    end
  end
end
