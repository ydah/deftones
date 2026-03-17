# frozen_string_literal: true

module Deftones
  module Core
    class AudioBlock
      attr_reader :channel_data

      def self.silent(num_frames, channels = 1)
        from_channel_data(Array.new([channels.to_i, 1].max) { Array.new(num_frames.to_i, 0.0) })
      end

      def self.from_channel_data(channel_data)
        normalized = channel_data.map { |channel| channel.map(&:to_f) }
        new(normalized)
      end

      def self.from_mono(samples, channels: 1)
        normalized = samples.map(&:to_f)
        from_channel_data(Array.new([channels.to_i, 1].max) { normalized.dup })
      end

      def initialize(channel_data)
        @channel_data = channel_data
      end

      def channels
        @channel_data.length
      end

      def num_frames
        @channel_data.first&.length || 0
      end

      def dup
        self.class.from_channel_data(@channel_data)
      end

      def mono
        return [] if @channel_data.empty?
        return @channel_data.first.dup if channels == 1

        Array.new(num_frames) do |frame_index|
          @channel_data.sum { |channel| channel[frame_index] } / channels.to_f
        end
      end

      def interleaved
        Array.new(num_frames * channels) do |index|
          frame_index = index / channels
          channel_index = index % channels
          @channel_data[channel_index][frame_index]
        end
      end

      def channel(index)
        @channel_data[index] || Array.new(num_frames, 0.0)
      end

      def fit_channels(target_channels)
        target = [target_channels.to_i, 1].max
        return dup if target == channels
        return self.class.from_channel_data([mono]) if target == 1

        if channels == 1
          return self.class.from_channel_data(Array.new(target) { @channel_data.first.dup })
        end

        self.class.from_channel_data(Array.new(target) { |index| channel(index % channels).dup })
      end

      def mix!(other)
        incoming = other.fit_channels(channels)
        channels.times do |channel_index|
          num_frames.times do |frame_index|
            @channel_data[channel_index][frame_index] += incoming.channel_data[channel_index][frame_index]
          end
        end
        self
      end
    end
  end
end
