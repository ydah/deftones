# frozen_string_literal: true

module Deftones
  module Analysis
    class Meter < Core::AudioNode
      attr_reader :peak, :rms
      attr_accessor :normal_range

      def initialize(smoothing: 0.8, normal_range: false, channels: 1, context: Deftones.context)
        super(context: context)
        @peak = 0.0
        @rms = 0.0
        @channels = [channels.to_i, 1].max
        @normal_range = !!normal_range
        self.smoothing = smoothing
      end

      def channels
        @channels
      end

      def smoothing
        @smoothing
      end

      def smoothing=(value)
        @smoothing = Deftones::DSP::Helpers.clamp(value.to_f, 0.0, 1.0)
      end

      def get_value
        return Deftones::DSP::Helpers.clamp(@rms, 0.0, 1.0) if @normal_range

        Deftones.gain_to_db([@rms.abs, 1.0e-12].max)
      end

      def process(input_buffer, num_frames, _start_frame, _cache)
        segment = input_buffer.first(num_frames)
        instantaneous_peak = segment.map(&:abs).max || 0.0
        instantaneous_rms = Math.sqrt(segment.sum { |sample| sample * sample } / [segment.length, 1].max)
        @peak = smooth(@peak, instantaneous_peak)
        @rms = smooth(@rms, instantaneous_rms)
        input_buffer
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
