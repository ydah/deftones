# frozen_string_literal: true

require "thread"

module Deftones
  module PortAudioSupport
    class << self
      def available?
        !!defined?(PortAudio)
      end

      def acquire!
        raise Deftones::MissingRealtimeBackendError, "PortAudio backend is unavailable" unless available?

        PortAudio.init
      rescue StandardError => error
        raise Deftones::MissingRealtimeBackendError, error.message
      end

      def release
        return unless available?

        PortAudio.terminate
      rescue StandardError
        nil
      end

      def output_parameters(channels)
        build_stream_parameters(direction: :output, channels: channels)
      end

      def input_parameters(channels)
        build_stream_parameters(direction: :input, channels: channels)
      end

      def check_error!(result, fallback: nil)
        PortAudio.check_error!(result)
      rescue StandardError => error
        raise Deftones::MissingRealtimeBackendError, fallback || error.message
      end

      private

      def build_stream_parameters(direction:, channels:)
        device =
          case direction
          when :input then PortAudio::Device.default_input
          when :output then PortAudio::Device.default_output
          else raise ArgumentError, "Unsupported PortAudio direction: #{direction}"
          end

        raise Deftones::MissingRealtimeBackendError, "No default #{direction} device available" unless device

        {
          device: device,
          channels: channels,
          format: :float32,
          latency: suggested_latency(device, direction)
        }
      rescue StandardError => error
        raise Deftones::MissingRealtimeBackendError, error.message
      end

      def suggested_latency(device, direction)
        direction == :input ? device.default_low_input_latency : device.default_low_output_latency
      end
    end
  end
end
