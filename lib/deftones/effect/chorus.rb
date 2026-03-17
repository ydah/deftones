# frozen_string_literal: true

module Deftones
  module Effects
    class Chorus < Core::Effect
      include ModulationControl

      attr_accessor :frequency, :depth, :delay_time, :feedback, :spread, :type

      def initialize(
        frequency: 1.5,
        depth: 0.003,
        delay_time: 0.015,
        feedback: 0.0,
        spread: 180.0,
        type: :sine,
        context: Deftones.context,
        **options
      )
        super(context: context, **options)
        @frequency = frequency.to_f
        @depth = depth.to_f
        @delay_time = delay_time.to_f
        @feedback = feedback.to_f
        @spread = spread.to_f
        @type = normalize_modulation_type(type)
        @phase = 0.0
        @delay_lines = []
        initialize_modulation_control
      end

      private

      def process_effect_block(input_block, num_frames, start_frame, _cache)
        output_channels = [input_block.channels, 2].max
        source = input_block.fit_channels(output_channels)
        ensure_delay_lines(output_channels)
        output = Array.new(output_channels) { Array.new(num_frames, 0.0) }

        num_frames.times do |index|
          current_time = (start_frame + index).to_f / context.sample_rate
          base_phase = modulation_phase_for(current_time)

          output_channels.times do |channel_index|
            phase = base_phase.nil? ? nil : base_phase + channel_phase_offset(channel_index, output_channels)
            modulation = unipolar_modulation_value(phase, default: 0.5)
            delay = (@delay_time + (@depth * modulation)) * context.sample_rate
            output[channel_index][index] = @delay_lines[channel_index].tap(
              delay,
              input_sample: source.channel_data[channel_index][index],
              feedback: @feedback
            )
          end
        end

        Core::AudioBlock.from_channel_data(output)
      end

      def ensure_delay_lines(channels)
        required = [channels.to_i, 1].max
        while @delay_lines.length < required
          @delay_lines << DSP::DelayLine.new((0.1 * context.sample_rate).ceil)
        end
      end

      def channel_phase_offset(channel_index, channels)
        return 0.0 if channels <= 1 || channel_index.zero?

        (@spread / 360.0) * (channel_index.to_f / [channels - 1, 1].max)
      end
    end
  end
end
