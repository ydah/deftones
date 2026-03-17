# frozen_string_literal: true

module Deftones
  module Analysis
    class Meter < Core::AudioNode
      attr_accessor :normal_range

      def initialize(smoothing: 0.8, normal_range: false, channels: 1, context: Deftones.context)
        super(context: context)
        @channels = [channels.to_i, 1].max
        @peak_values = Array.new(@channels, 0.0)
        @rms_values = Array.new(@channels, 0.0)
        @normal_range = !!normal_range
        self.smoothing = smoothing
      end

      def channels
        @channels
      end

      def peak
        @peak_values.length == 1 ? @peak_values.first : @peak_values.dup
      end

      def rms
        @rms_values.length == 1 ? @rms_values.first : @rms_values.dup
      end

      def smoothing
        @smoothing
      end

      def smoothing=(value)
        @smoothing = Deftones::DSP::Helpers.clamp(value.to_f, 0.0, 1.0)
      end

      def get_value
        values = @rms_values.map do |value|
          if @normal_range
            Deftones::DSP::Helpers.clamp(value, 0.0, 1.0)
          else
            Deftones.gain_to_db([value.abs, 1.0e-12].max)
          end
        end

        values.length == 1 ? values.first : values
      end

      def multichannel_process?
        true
      end

      def process(input_block, num_frames, _start_frame, _cache)
        analysis_block = input_block.fit_channels(@channels)

        @channels.times do |channel_index|
          segment = analysis_block.channel_data[channel_index].first(num_frames)
          instantaneous_peak = segment.map(&:abs).max || 0.0
          instantaneous_rms = Math.sqrt(segment.sum { |sample| sample * sample } / [segment.length, 1].max)
          @peak_values[channel_index] = smooth(@peak_values[channel_index], instantaneous_peak)
          @rms_values[channel_index] = smooth(@rms_values[channel_index], instantaneous_rms)
        end

        input_block
      end

      alias getValue get_value
      alias normalRange normal_range

      def normalRange=(value)
        self.normal_range = value
      end

      private

      def smooth(previous, current)
        return current if @smoothing.zero?

        (previous.to_f * @smoothing) + (current.to_f * (1.0 - @smoothing))
      end
    end
  end
end
