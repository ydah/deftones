# frozen_string_literal: true

module Deftones
  module IO
    class Recorder
      attr_reader :state, :mime_type, :captured_buffer

      MIME_TYPES = {
        wav: "audio/wav",
        mp3: "audio/mpeg",
        ogg: "audio/ogg"
      }.freeze

      def initialize(context:, node: nil, mime_type: "audio/wav")
        @context = context
        @node = node || context.output
        @captured_buffer = nil
        @mime_type = mime_type
        @state = :stopped
        @started_at = nil
        @recorded_duration = 0.0
      end

      def start
        @captured_buffer = nil
        @started_at = @context.current_time
        @state = :started
        self
      end

      def stop(path: nil, format: nil, duration: nil)
        return @captured_buffer if @state == :stopped && @captured_buffer

        @recorded_duration = duration || elapsed_duration
        @captured_buffer = capture_buffer(duration: @recorded_duration)
        @state = :stopped
        save(path, format: resolve_format(format, path)) if path
        @captured_buffer
      end

      def record(duration: nil, format: :wav, path: nil)
        start
        stop(path: path, format: format, duration: duration)
      end

      def save(path, format: :wav)
        raise ArgumentError, "Nothing recorded yet" unless @captured_buffer

        @captured_buffer.save(path, format: format)
      end

      def dispose
        @captured_buffer = nil
        @state = :stopped
        @started_at = nil
        @recorded_duration = 0.0
        self
      end

      alias mimeType mime_type

      private

      def capture_buffer(duration:)
        if @context.is_a?(Deftones::OfflineContext)
          @context.render
        else
          seconds = [duration.to_f, 1.0 / @context.sample_rate].max
          frames = (seconds * @context.sample_rate).ceil
          block = @node.send(:render_block, frames, 0, {}).fit_channels(@context.channels)
          Buffer.new(block.interleaved, channels: @context.channels, sample_rate: @context.sample_rate)
        end
      end

      def elapsed_duration
        return 0.0 unless @started_at

        [@context.current_time - @started_at, 0.0].max
      end

      def resolve_format(format, path)
        return format if format
        return File.extname(path).delete_prefix(".").downcase.to_sym if path

        MIME_TYPES.key(@mime_type) || :wav
      end
    end
  end
end
