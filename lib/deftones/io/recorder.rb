# frozen_string_literal: true

module Deftones
  module IO
    class Recorder
      def initialize(context:, node: nil)
        @context = context
        @node = node || context.output
        @captured_buffer = nil
      end

      def record(duration: nil, format: :wav, path: nil)
        @captured_buffer =
          if @context.is_a?(Deftones::OfflineContext)
            @context.render
          else
            frames = ((duration || 1.0).to_f * @context.sample_rate).ceil
            samples = Buffer.interleave(@node.render(frames, 0, {}), @context.channels)
            Buffer.new(samples, channels: @context.channels, sample_rate: @context.sample_rate)
          end

        @captured_buffer.save(path, format: format) if path
        @captured_buffer
      end

      def save(path, format: :wav)
        raise ArgumentError, "Nothing recorded yet" unless @captured_buffer

        @captured_buffer.save(path, format: format)
      end
    end
  end
end
