# frozen_string_literal: true

module Deftones
  module Source
    class OmniOscillator < Core::Source
      SNAPSHOT_OPTION_KEYS = %i[
        count
        detune
        frequency
        harmonicity
        modulation_depth
        modulation_frequency
        modulation_index
        phase
        spread
        type
        width
      ].freeze

      TYPE_MAP = {
        sine: Oscillator,
        square: Oscillator,
        triangle: Oscillator,
        sawtooth: Oscillator,
        pulse: PulseOscillator,
        pwm: PWMOscillator,
        fm: FMOscillator,
        am: AMOscillator,
        fat: FatOscillator
      }.freeze

      attr_reader :source
      attr_accessor :type

      def initialize(type: :sine, context: Deftones.context, **options)
        super(context: context)
        @type = type.to_sym
        @options = options
        rebuild_source
      end

      def type=(value)
        @type = value.to_sym
        rebuild_source
      end

      def frequency
        @source.frequency if @source.respond_to?(:frequency)
      end

      def start(time = nil)
        @source.start(time)
        self
      end

      def stop(time = nil)
        @source.stop(time)
        self
      end

      def restart(time = nil)
        @source.restart(time)
        self
      end

      def cancel_stop
        @source.cancel_stop
        self
      end

      def sync
        @source.sync
        self
      end

      def unsync
        @source.unsync
        self
      end

      def synced?
        @source.synced?
      end

      def state(time = context.current_time)
        @source.state(time)
      end

      def onstop
        @source.onstop
      end

      def onstop=(callback)
        @source.onstop = callback
      end

      def process(_input_buffer, num_frames, start_frame, cache)
        @source.render(num_frames, start_frame, cache)
      end

      alias cancelStop cancel_stop

      def method_missing(method_name, *arguments, &block)
        return super unless @source.respond_to?(method_name)

        @source.public_send(method_name, *arguments, &block)
      end

      def respond_to_missing?(method_name, include_private = false)
        @source.respond_to?(method_name, include_private) || super
      end

      private

      def rebuild_source
        source_class = TYPE_MAP.fetch(@type) { Oscillator }
        snapshot = snapshot_source(@source)
        source_options = build_source_options(source_class, snapshot.fetch(:options, {}))
        @source = source_class.new(**source_options)
        apply_snapshot(@source, snapshot)
      end

      def build_source_options(source_class, snapshot_options)
        allowed_keys = source_class.instance_method(:initialize).parameters.filter_map do |kind, name|
          name if %i[key keyreq].include?(kind)
        end

        @options
          .merge(snapshot_options)
          .merge(context: context)
          .then do |options|
            options[:type] = @type if source_class == Oscillator
            options.select { |key, _value| allowed_keys.include?(key) }
          end
      end

      def snapshot_source(source)
        return { options: {} } unless source

        {
          options: snapshot_source_options(source),
          mute: source.respond_to?(:mute?) ? source.mute? : false,
          onstop: source.respond_to?(:onstop) ? source.onstop : nil,
          start_time: source.instance_variable_get(:@start_time),
          stop_notified: source.instance_variable_get(:@stop_notified),
          stop_time: source.instance_variable_get(:@stop_time),
          synced: source.respond_to?(:synced?) ? source.synced? : false,
          volume: source.respond_to?(:volume) ? source.volume.value : 0.0
        }
      end

      def snapshot_source_options(source)
        SNAPSHOT_OPTION_KEYS.each_with_object({}) do |key, options|
          next unless source.respond_to?(key)

          value = source.public_send(key)
          options[key] = value.respond_to?(:value) ? value.value : value
        end
      end

      def apply_snapshot(source, snapshot)
        return source if snapshot.empty?

        source.volume.value = snapshot[:volume] if source.respond_to?(:volume) && snapshot.key?(:volume)
        source.mute = snapshot[:mute] if source.respond_to?(:mute=) && snapshot.key?(:mute)
        source.onstop = snapshot[:onstop] if source.respond_to?(:onstop=) && snapshot.key?(:onstop)
        source.instance_variable_set(:@start_time, snapshot[:start_time]) if snapshot.key?(:start_time)
        source.instance_variable_set(:@stop_time, snapshot[:stop_time]) if snapshot.key?(:stop_time)
        source.instance_variable_set(:@stop_notified, snapshot[:stop_notified]) if snapshot.key?(:stop_notified)
        source.sync if snapshot[:synced] && source.respond_to?(:sync)
        source
      end
    end
  end
end
