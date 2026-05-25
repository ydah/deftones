# frozen_string_literal: true

require "thread"

module Deftones
  module PortAudioSupport
    class << self
      def available?
        load_backend!
        !!defined?(PortAudio)
      end

      def acquire!
        raise Deftones::MissingRealtimeBackendError, "PortAudio backend is unavailable" unless available?

        mutex.synchronize do
          PortAudio.init if ref_count.zero?
          @ref_count = ref_count + 1
        end
        self
      rescue StandardError => error
        raise Deftones::MissingRealtimeBackendError, error.message
      end

      def release
        return unless available?

        mutex.synchronize do
          return self if ref_count.zero?

          @ref_count = ref_count - 1
          PortAudio.terminate if ref_count.zero?
        end
        self
      rescue StandardError
        nil
      end

      def output_parameters(channels, device_id: nil, label: nil, sample_rate: nil)
        build_stream_parameters(
          direction: :output,
          channels: channels,
          device_id: device_id,
          label: label,
          sample_rate: sample_rate
        )
      end

      def input_parameters(channels, device_id: nil, label: nil, sample_rate: nil)
        build_stream_parameters(
          direction: :input,
          channels: channels,
          device_id: device_id,
          label: label,
          sample_rate: sample_rate
        )
      end

      def check_error!(result, fallback: nil)
        PortAudio.check_error!(result)
      rescue StandardError => error
        raise Deftones::MissingRealtimeBackendError, fallback || error.message
      end

      private

      def load_backend!
        return true if defined?(PortAudio)

        require "portaudio"
        true
      rescue LoadError
        false
      end

      def mutex
        @mutex ||= Mutex.new
      end

      def ref_count
        @ref_count ||= 0
      end

      def build_stream_parameters(direction:, channels:, device_id: nil, label: nil, sample_rate: nil)
        device =
          resolve_device(direction: direction, device_id: device_id, label: label)

        raise Deftones::MissingRealtimeBackendError, "No default #{direction} device available" unless device
        detect_sample_rate_mismatch!(device, sample_rate) if sample_rate

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
        matcher = label.is_a?(Regexp) ? label : Regexp.new(Regexp.escape(label.to_s), Regexp::IGNORECASE)
        candidates.compact.any? { |candidate| candidate.to_s.match?(matcher) }
      end

      def suggested_latency(device, direction)
        method_name = direction == :input ? :default_low_input_latency : :default_low_output_latency
        return device.public_send(method_name) if device.respond_to?(method_name)

        0.05
      end

      def detect_sample_rate_mismatch!(device, requested_sample_rate)
        device_sample_rate =
          if device.respond_to?(:default_sample_rate)
            device.default_sample_rate
          elsif device.respond_to?(:sample_rate)
            device.sample_rate
          end
        return unless device_sample_rate
        return if device_sample_rate.to_f == requested_sample_rate.to_f

        raise Deftones::MissingRealtimeBackendError,
              "PortAudio device sample rate #{device_sample_rate} does not match requested #{requested_sample_rate}"
      end
    end
  end
end
