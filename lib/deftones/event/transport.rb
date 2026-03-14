# frozen_string_literal: true

module Deftones
  module Event
    class Transport
      attr_accessor :bpm, :loop, :loop_start, :loop_end
      attr_reader :state, :time_signature

      def initialize(bpm: 120.0, time_signature: [4, 4])
        @bpm = bpm.to_f
        @state = :stopped
        self.time_signature = time_signature
        @loop = false
        @loop_start = 0.0
        @loop_end = 0.0
      end

      def start(_time = nil)
        @state = :started
        self
      end

      def stop(_time = nil)
        @state = :stopped
        self
      end

      def pause(_time = nil)
        @state = :paused
        self
      end

      def cancel(_after_time = 0)
        self
      end

      def time_signature=(signature)
        @time_signature =
          case signature
          when Array then signature.map(&:to_i)
          else [signature.to_i, 4]
          end
      end
    end
  end
end
