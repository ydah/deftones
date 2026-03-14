# frozen_string_literal: true

module Deftones
  module Source
    class UserMedia < Core::Source
      attr_reader :buffer, :provider

      def initialize(buffer: nil, provider: nil, loop: false, context: Deftones.context)
        super(context: context)
        @buffer = normalize_buffer(buffer)
        @provider = normalize_provider(provider)
        @loop = loop
        @sample_cursor = 0
      end

      def start(time = nil)
        rewind
        super
      end

      def rewind
        @sample_cursor = 0
        @provider.rewind if @provider.respond_to?(:rewind)
        self
      end

      def process(_input_buffer, num_frames, start_frame, _cache)
        return render_buffer(num_frames, start_frame) if @buffer

        Array.new(num_frames) do |index|
          current_time = (start_frame + index).to_f / context.sample_rate
          next 0.0 unless active_at?(current_time)

          next_provider_sample
        end
      end

      private

      def normalize_buffer(buffer)
        return if buffer.nil?

        buffer.is_a?(IO::Buffer) ? buffer : IO::Buffer.load(buffer)
      end

      def normalize_provider(provider)
        return if provider.nil?
        return provider if provider.respond_to?(:call)

        provider.to_enum
      end

      def render_buffer(num_frames, start_frame)
        Array.new(num_frames) do |index|
          current_time = (start_frame + index).to_f / context.sample_rate
          next 0.0 unless active_at?(current_time)

          sample_position = (current_time - @start_time) * @buffer.sample_rate
          if @loop && @buffer.frames.positive?
            sample_position %= @buffer.frames
          elsif sample_position >= @buffer.frames
            next 0.0
          end

          @buffer.sample_at(sample_position)
        end
      end

      def next_provider_sample
        return 0.0 unless @provider

        sample = if @provider.respond_to?(:call)
          @provider.call(@sample_cursor)
        else
          next_enumerator_sample
        end
        @sample_cursor += 1
        sample.to_f
      end

      def next_enumerator_sample
        @provider.next
      rescue StopIteration
        return 0.0 unless @loop && @provider.respond_to?(:rewind)

        @provider.rewind
        @provider.next
      rescue StopIteration
        0.0
      end
    end
  end
end
