# frozen_string_literal: true

module Deftones
  module Core
    class Param < Signal
      attr_reader :lfo, :audio_source, :modulation_amount

      def initialize(**options)
        super
        @lfo = nil
        @audio_source = nil
        @modulation_amount = 1.0
      end

      def set_param(param)
        @param = param
        self
      end

      def connect(destination, output_index: 0, input_index: 0)
        super
        @param = destination if destination.respond_to?(:value=)
        self
      end

      def lfo=(source)
        @lfo = source
      end

      def connect_audio(source, amount: 1.0)
        raise ArgumentError, "audio source is required" if source.nil?
        raise ArgumentError, "audio source must render or process samples" unless modulation_source?(source)

        @audio_source = source
        @modulation_amount = amount.to_f
        self
      end

      def disconnect_audio(source = nil)
        return self if source && source != @audio_source

        @audio_source = nil
        @modulation_amount = 1.0
        self
      end

      def audio_rate?
        !@audio_source.nil?
      end

      def process(num_frames, start_frame = 0)
        values = super
        return values unless @audio_source

        modulation = modulation_samples(num_frames, start_frame)
        values.zip(modulation).map { |base, sample| base + (sample.to_f * @modulation_amount) }
      end

      alias setParam set_param
      alias connectAudio connect_audio
      alias disconnectAudio disconnect_audio
      alias audioRate audio_rate?

      private

      def modulation_source?(source)
        source.respond_to?(:values) || source.respond_to?(:process) || source.respond_to?(:render)
      end

      def modulation_samples(num_frames, start_frame)
        if @audio_source.respond_to?(:values)
          @audio_source.values(num_frames, start_frame)
        elsif @audio_source.respond_to?(:render)
          @audio_source.render(num_frames, start_frame)
        else
          @audio_source.process(num_frames, start_frame)
        end
      end
    end
  end
end
