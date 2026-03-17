# frozen_string_literal: true

module Deftones
  module Effects
    class Phaser < Core::Effect
      include ModulationControl

      attr_accessor :frequency, :octaves, :q, :base_frequency, :stages, :type

      def initialize(
        frequency: 0.5,
        octaves: 3.0,
        q: 0.8,
        base_frequency: 300.0,
        stages: 4,
        type: :sine,
        context: Deftones.context,
        **options
      )
        super(context: context, **options)
        @frequency = frequency.to_f
        @octaves = octaves.to_f
        @q = q.to_f
        @base_frequency = base_frequency.to_f
        @stages = stages.to_i
        @type = normalize_modulation_type(type)
        @phase = 0.0
        @filters = []
        initialize_modulation_control
      end

      def stages=(value)
        @stages = [value.to_i, 1].max
      end

      private

      def process_effect_block(input_block, num_frames, start_frame, _cache)
        filter_banks = stage_filters(input_block.channels)
        output = Array.new(input_block.channels) { Array.new(num_frames, 0.0) }

        num_frames.times do |index|
          current_time = (start_frame + index).to_f / context.sample_rate
          phase = modulation_phase_for(current_time)
          modulation = unipolar_modulation_value(phase, default: 0.5)
          input_block.channel_data.each_with_index do |channel, channel_index|
            output[channel_index][index] = filter_banks[channel_index].each_with_index.reduce(channel[index]) do |sample, (filter, stage_index)|
              stage_position = @stages == 1 ? 0.0 : (stage_index.to_f / (@stages - 1)) - 0.5
              cutoff = @base_frequency * (2.0**((modulation * @octaves) + (stage_position * 0.5)))
              filter.update(type: :notch, frequency: cutoff, q: @q, gain_db: 0.0, sample_rate: context.sample_rate)
              filter.process_sample(sample)
            end
          end
        end

        Core::AudioBlock.from_channel_data(output)
      end

      def stage_filters(channels)
        required_channels = [channels.to_i, 1].max
        while @filters.length < required_channels
          @filters << Array.new(@stages) { DSP::Biquad.new }
        end

        @filters.map! do |bank|
          bank.length == @stages ? bank : Array.new(@stages) { DSP::Biquad.new }
        end
        @filters
      end
    end
  end
end
