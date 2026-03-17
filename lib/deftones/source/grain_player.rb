# frozen_string_literal: true

module Deftones
  module Source
    class GrainPlayer < Player
      attr_reader :detune
      attr_accessor :grain_size, :overlap, :jitter

      def initialize(grain_size: 0.05, overlap: 0.5, jitter: 0.002, detune: 0.0, **options)
        super(**options)
        @grain_size = grain_size.to_f
        @overlap = overlap.to_f
        @jitter = jitter.to_f
        @detune = Core::Signal.new(value: detune, units: :number, context: context)
      end

      def detune=(value)
        @detune.value = value
      end

      def process(_input_buffer, num_frames, start_frame, _cache)
        rates = @playback_rate.process(num_frames, start_frame)
        detunes = @detune.process(num_frames, start_frame)
        grain_duration = grain_duration_seconds
        overlap_duration = overlap_duration_seconds(grain_duration)
        grain_interval = grain_interval_seconds(grain_duration, overlap_duration)
        active_grains = active_grain_count(grain_duration, grain_interval)
        return process_multichannel_buffer(num_frames, start_frame, rates, detunes, grain_duration, overlap_duration, grain_interval, active_grains) if multichannel_process?

        Array.new(num_frames) do |index|
          current_time = (start_frame + index).to_f / context.sample_rate
          notify_stop(current_time) if @stop_time && current_time >= @stop_time
          next 0.0 unless active_at?(current_time)

          rate = positive_rate(rates[index])
          output = granular_sample(
            current_time,
            playback_rate: rate,
            detune_ratio: detune_ratio(detunes[index]),
            grain_duration: grain_duration,
            overlap_duration: overlap_duration,
            grain_interval: grain_interval,
            active_grains: active_grains
          )

          if naturally_finished?(current_time, rate, grain_duration)
            @stop_time ||= current_time
            notify_stop(current_time)
            next 0.0
          end

          output * envelope_gain(current_time)
        end
      end

      private

      def process_multichannel_buffer(num_frames, start_frame, rates, detunes, grain_duration, overlap_duration, grain_interval, active_grains)
        output = Array.new(@buffer.channels) { Array.new(num_frames, 0.0) }

        num_frames.times do |index|
          current_time = (start_frame + index).to_f / context.sample_rate
          notify_stop(current_time) if @stop_time && current_time >= @stop_time
          next unless active_at?(current_time)

          rate = positive_rate(rates[index])
          detune = detune_ratio(detunes[index])

          @buffer.channels.times do |channel_index|
            output[channel_index][index] = granular_sample(
              current_time,
              playback_rate: rate,
              detune_ratio: detune,
              grain_duration: grain_duration,
              overlap_duration: overlap_duration,
              grain_interval: grain_interval,
              active_grains: active_grains,
              channel_index: channel_index
            )
          end

          if naturally_finished?(current_time, rate, grain_duration)
            @stop_time ||= current_time
            notify_stop(current_time)
          else
            gain = envelope_gain(current_time)
            @buffer.channels.times do |channel_index|
              output[channel_index][index] *= gain
            end
          end
        end

        Core::AudioBlock.from_channel_data(output)
      end

      def granular_sample(current_time, playback_rate:, detune_ratio:, grain_duration:, overlap_duration:, grain_interval:,
                          active_grains:, channel_index: nil)
        current_grain = grain_index_at(current_time, grain_interval)
        first_grain = [current_grain - active_grains, 0].max

        (first_grain..current_grain).sum(0.0) do |grain_index|
          grain_elapsed = current_time - grain_start_time(grain_index, grain_interval)
          next 0.0 if grain_elapsed.negative? || grain_elapsed >= grain_duration

          logical_position = grain_logical_position(grain_index, grain_elapsed, playback_rate, detune_ratio, grain_interval)
          sample_position = resolve_buffer_position(logical_position)
          next 0.0 if sample_position.negative?

          sample =
            if channel_index.nil?
              @buffer.sample_at(sample_position)
            else
              @buffer.sample_at(sample_position, channel_index)
            end
          sample * grain_window_gain(grain_elapsed, grain_duration, overlap_duration)
        end
      end

      def grain_duration_seconds
        [@grain_size.to_f, context.sample_time].max
      end

      def overlap_duration_seconds(grain_duration)
        @overlap.to_f.clamp(0.0, grain_duration)
      end

      def grain_interval_seconds(grain_duration, overlap_duration)
        [grain_duration - overlap_duration, context.sample_time].max
      end

      def active_grain_count(grain_duration, grain_interval)
        [(grain_duration / grain_interval).ceil + 1, 1].max
      end

      def grain_index_at(current_time, grain_interval)
        ((current_time - @start_time) / grain_interval).floor
      end

      def grain_start_time(grain_index, grain_interval)
        @start_time + (grain_index * grain_interval)
      end

      def grain_logical_position(grain_index, grain_elapsed, playback_rate, detune_ratio, grain_interval)
        anchor = @seek_position + grain_anchor_offset(grain_index, playback_rate, grain_interval)
        anchor + grain_jitter_offset(grain_index) + (grain_elapsed * @buffer.sample_rate * detune_ratio)
      end

      def grain_anchor_offset(grain_index, playback_rate, grain_interval)
        grain_index * grain_interval * @buffer.sample_rate * playback_rate
      end

      def grain_jitter_offset(grain_index)
        return 0.0 if @jitter.zero?

        ((grain_random(grain_index) * 2.0) - 1.0) * @jitter * @buffer.sample_rate
      end

      def grain_random(grain_index)
        Math.sin((grain_index + 1) * 12_989.0).abs % 1.0
      end

      def grain_window_gain(grain_elapsed, grain_duration, overlap_duration)
        return 1.0 if overlap_duration <= 0.0

        fade_in = (grain_elapsed / overlap_duration).clamp(0.0, 1.0)
        fade_out = ((grain_duration - grain_elapsed) / overlap_duration).clamp(0.0, 1.0)
        [fade_in, fade_out].min
      end

      def naturally_finished?(current_time, playback_rate, grain_duration)
        return false if @loop
        return false unless playback_rate.positive?

        current_time >= natural_stop_time(playback_rate, grain_duration)
      end

      def natural_stop_time(playback_rate, grain_duration)
        @start_time + (playable_frame_span / (@buffer.sample_rate * playback_rate)) + grain_duration
      end

      def playable_frame_span
        return [@buffer.frames - @seek_position, 0.0].max unless @reverse

        min_position = @loop_start * @buffer.sample_rate
        max_position = loop_end_frame || (@buffer.frames - 1)
        [max_position - min_position - @seek_position, 0.0].max
      end

      def positive_rate(value)
        [value.to_f.abs, Float::EPSILON].max
      end

      def detune_ratio(cents)
        2.0**(cents.to_f / 1200.0)
      end
    end
  end
end
