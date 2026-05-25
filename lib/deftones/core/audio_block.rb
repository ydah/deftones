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

      def self.from_interleaved(samples, channels:)
        channel_count = [channels.to_i, 1].max
        normalized = Array(samples).map(&:to_f)
        frame_count = (normalized.length.to_f / channel_count).ceil
        from_channel_data(
          Array.new(channel_count) do |channel_index|
            Array.new(frame_count) do |frame_index|
              normalized[(frame_index * channel_count) + channel_index] || 0.0
            end
          end
        )
      end

      def self.from_packed_float32(payload, channels:)
        from_interleaved(payload.unpack("e*"), channels: channels)
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

      def packed_float32
        interleaved.pack("e*")
      end

      def packed_float64
        interleaved.pack("E*")
      end

      def channel(index)
        @channel_data[index] || Array.new(num_frames, 0.0)
      end

      def fit_channels(target_channels, downmix: :average, upmix: :wrap)
        target = [target_channels.to_i, 1].max
        return dup if target == channels
        return self.class.from_channel_data([downmixed_channel(downmix)]) if target == 1

        if channels == 1
          return self.class.from_channel_data(Array.new(target) { @channel_data.first.dup })
        end

        self.class.from_channel_data(Array.new(target) { |index| upmixed_channel(index, upmix) })
      end

      def mix!(other, headroom: :sum, gain: 1.0)
        incoming = other.fit_channels(channels)
        channels.times do |channel_index|
          num_frames.times do |frame_index|
            mixed = @channel_data[channel_index][frame_index] + (incoming.channel_data[channel_index][frame_index] * gain)
            @channel_data[channel_index][frame_index] = apply_headroom(mixed, headroom)
          end
        end
        self
      end

      private

      def downmixed_channel(policy)
        case policy
        when :average then mono
        when :sum
          Array.new(num_frames) { |frame_index| @channel_data.sum { |channel| channel[frame_index] } }
        when :first
          channel(0).dup
        else
          raise ArgumentError, "Unsupported downmix policy: #{policy}"
        end
      end

      def upmixed_channel(index, policy)
        case policy
        when :wrap then channel(index % channels).dup
        when :silence then index < channels ? channel(index).dup : Array.new(num_frames, 0.0)
        when :duplicate then channel([index, channels - 1].min).dup
        else
          raise ArgumentError, "Unsupported upmix policy: #{policy}"
        end
      end

      def apply_headroom(sample, policy)
        case policy
        when :sum then sample
        when :clamp then sample.clamp(-1.0, 1.0)
        else
          raise ArgumentError, "Unsupported headroom policy: #{policy}"
        end
      end
    end
  end
end
