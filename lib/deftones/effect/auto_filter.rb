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
        @biquad = DSP::Biquad.new
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

      def process_effect(input_buffer, num_frames, start_frame, _cache)
        Array.new(num_frames) do |index|
          current_time = (start_frame + index).to_f / context.sample_rate
          phase = modulation_phase_for(current_time)
          modulation = unipolar_modulation_value(phase, default: 0.5) * @depth.clamp(0.0, 1.0)
          cutoff = @base_frequency * (2.0**(modulation * @octaves))
          @biquad.update(
            type: @filter.type,
            frequency: cutoff,
            q: @filter.q,
            gain_db: 0.0,
            sample_rate: context.sample_rate
          )
          @biquad.process_sample(input_buffer[index])
        end
      end

      def resolve_filter(filter, filter_type:, q:)
        return filter if filter.respond_to?(:type) && filter.respond_to?(:q)

        FilterProxy.new(type: filter_type.to_sym, q: q.to_f, rolloff: -12)
      end
    end
  end
end
