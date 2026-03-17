# frozen_string_literal: true

module Deftones
  module Effects
    class AutoFilter < Core::Effect
      include ModulationControl

      FilterProxy = Struct.new(:type, :q, :rolloff, keyword_init: true)

      attr_accessor :frequency, :octaves, :depth, :base_frequency, :type
      attr_reader :filter

      def initialize(
        frequency: 1.0,
        base_frequency: 200.0,
        octaves: 2.5,
        depth: 1.0,
        type: :sine,
        filter_type: :lowpass,
        q: 0.8,
        filter: nil,
        context: Deftones.context,
        **options
      )
        super(context: context, wet: 1.0, **options)
        @frequency = frequency.to_f
        @base_frequency = base_frequency.to_f
        @octaves = octaves.to_f
        @depth = depth.to_f
        @type = normalize_modulation_type(type)
        @filter = resolve_filter(filter, filter_type: filter_type, q: q)
        @phase = 0.0
        @biquads = []
        initialize_modulation_control
      end

      def q
        @filter.q
      end

      def q=(value)
        @filter.q = value.to_f
      end

      alias baseFrequency base_frequency

      def baseFrequency=(value)
        self.base_frequency = value
      end

      private

      def process_effect_block(input_block, num_frames, start_frame, _cache)
        ensure_biquads(input_block.channels)
        output = Array.new(input_block.channels) { Array.new(num_frames, 0.0) }

        num_frames.times do |index|
          current_time = (start_frame + index).to_f / context.sample_rate
          phase = modulation_phase_for(current_time)
          modulation = unipolar_modulation_value(phase, default: 0.5) * @depth.clamp(0.0, 1.0)
          cutoff = @base_frequency * (2.0**(modulation * @octaves))
          input_block.channel_data.each_with_index do |channel, channel_index|
            biquad = @biquads[channel_index]
            biquad.update(
              type: @filter.type,
              frequency: cutoff,
              q: @filter.q,
              gain_db: 0.0,
              sample_rate: context.sample_rate
            )
            output[channel_index][index] = biquad.process_sample(channel[index])
          end
        end

        Core::AudioBlock.from_channel_data(output)
      end

      def resolve_filter(filter, filter_type:, q:)
        return filter if filter.respond_to?(:type) && filter.respond_to?(:q)

        FilterProxy.new(type: filter_type.to_sym, q: q.to_f, rolloff: -12)
      end

      def ensure_biquads(channels)
        required = [channels.to_i, 1].max
        while @biquads.length < required
          @biquads << DSP::Biquad.new
        end
      end
    end
  end
end
