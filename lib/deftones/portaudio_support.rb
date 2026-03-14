# frozen_string_literal: true

require "thread"

module Deftones
  module PortAudioSupport
    @mutex = Mutex.new
    @session_count = 0

    class << self
      def available?
        !!defined?(FFI::PortAudio::API)
      end

      def acquire!
        raise Deftones::MissingRealtimeBackendError, "PortAudio backend is unavailable" unless available?

        @mutex.synchronize do
          if @session_count.zero?
            result = FFI::PortAudio::API.Pa_Initialize
            check_error!(result)
          end

          @session_count += 1
        end
      end

      def release
        return unless available?

        @mutex.synchronize do
          return if @session_count.zero?

          @session_count -= 1
          return unless @session_count.zero?

          result = FFI::PortAudio::API.Pa_Terminate
          check_error!(result)
        end
      rescue StandardError
        @session_count = 0
      end

      def output_parameters(channels)
        build_stream_parameters(direction: :output, channels: channels)
      end

      def input_parameters(channels)
        build_stream_parameters(direction: :input, channels: channels)
      end

      def check_error!(result, fallback: nil)
        return result if result == :paNoError || result == 0

        raise Deftones::MissingRealtimeBackendError, fallback || error_message(result)
      end

      private

      def build_stream_parameters(direction:, channels:)
        api = FFI::PortAudio::API
        device =
          case direction
          when :input then api.Pa_GetDefaultInputDevice
          when :output then api.Pa_GetDefaultOutputDevice
          else raise ArgumentError, "Unsupported PortAudio direction: #{direction}"
          end

        if device == api::NoDevice
          raise Deftones::MissingRealtimeBackendError, "No default #{direction} device available"
        end

        info = api.Pa_GetDeviceInfo(device)
        parameters = api::PaStreamParameters.new
        parameters[:device] = device
        parameters[:channelCount] = channels
        parameters[:sampleFormat] = api::Float32
        parameters[:suggestedLatency] = suggested_latency(info, direction)
        parameters[:hostApiSpecificStreamInfo] = nil
        parameters
      end

      def suggested_latency(info, direction)
        direction == :input ? info[:defaultLowInputLatency] : info[:defaultLowOutputLatency]
      end

      def error_message(result)
        return result.to_s if result.is_a?(Symbol)

        FFI::PortAudio::API.Pa_GetErrorText(result)
      end
    end
  end
end
