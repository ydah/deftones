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

      def input_parameters(channels, device_id: nil, label: nil)
        build_stream_parameters(direction: :input, channels: channels, device_id: device_id, label: label)
      end

      def check_error!(result, fallback: nil)
        PortAudio.check_error!(result)
      rescue StandardError => error
        raise Deftones::MissingRealtimeBackendError, fallback || error.message
      end

      private

      def build_stream_parameters(direction:, channels:, device_id: nil, label: nil)
        device =
          resolve_device(direction: direction, device_id: device_id, label: label)

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

      def resolve_device(direction:, device_id:, label:)
        return default_device(direction) if device_id.nil? && label.nil?

        devices =
          if PortAudio::Device.respond_to?(:all)
            Array(PortAudio::Device.all)
          elsif PortAudio::Device.respond_to?(:devices)
            Array(PortAudio::Device.devices)
          else
            []
          end

        matched = devices.find do |device|
          matches_device_id?(device, device_id) || matches_device_label?(device, label)
        end
        return matched if matched

        raise Deftones::MissingRealtimeBackendError, "No matching #{direction} device available"
      end

      def default_device(direction)
        case direction
        when :input then PortAudio::Device.default_input
        when :output then PortAudio::Device.default_output
        else raise ArgumentError, "Unsupported PortAudio direction: #{direction}"
        end
      end

      def matches_device_id?(device, device_id)
        return false if device_id.nil?

        candidates = []
        candidates << device.device_id if device.respond_to?(:device_id)
        candidates << device.index if device.respond_to?(:index)
        candidates << device.device_index if device.respond_to?(:device_index)
        candidates.compact.any? { |candidate| candidate.to_s == device_id.to_s }
      end

      def matches_device_label?(device, label)
        return false if label.nil?

        candidates = []
        candidates << device.label if device.respond_to?(:label)
        candidates << device.name if device.respond_to?(:name)
        candidates.compact.any? { |candidate| candidate.to_s == label.to_s }
      end

      def suggested_latency(device, direction)
        direction == :input ? device.default_low_input_latency : device.default_low_output_latency
      end
    end
  end
end
