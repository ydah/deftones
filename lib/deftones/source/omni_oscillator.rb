# frozen_string_literal: true

module Deftones
  module Source
    class OmniOscillator < Core::Source
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

      def process(_input_buffer, num_frames, start_frame, cache)
        @source.render(num_frames, start_frame, cache)
      end

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
        source_options = @options.merge(context: context)
        source_options[:type] = @type if source_class == Oscillator
        @source = source_class.new(**source_options)
      end
    end
  end
end
