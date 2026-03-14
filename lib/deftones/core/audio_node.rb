# frozen_string_literal: true

module Deftones
  module Core
    class AudioNode
      attr_reader :context, :input

      def initialize(context: Deftones.context)
        @context = context
        @input = self
        @sources = []
        @destinations = []
        @disposed = false
      end

      def output
        self
      end

      def connect(destination, output_index: 0, input_index: 0)
        _ = output_index
        _ = input_index
        raise ArgumentError, "destination is required" if destination.nil?

        destination_node = destination.respond_to?(:input) ? destination.input : destination
        output.attach_destination(destination_node)
        self
      end

      def disconnect(destination = nil)
        if destination
          destination_node = destination.respond_to?(:input) ? destination.input : destination
          output.detach_destination(destination_node)
        else
          output.detach_all_destinations
        end
        self
      end

      def >>(other)
        connect(other)
        other
      end

      def chain(*nodes)
        [self, *nodes].each_cons(2) { |source, destination| source.connect(destination) }
        nodes.last || self
      end

      def fan(*nodes)
        nodes.each { |node| connect(node) }
        self
      end

      def to_output
        connect(context.output)
        self
      end

      def dispose
        disconnect
        @sources.dup.each { |source| source.detach_destination(self) }
        @sources.clear
        @disposed = true
        self
      end

      def disposed?
        @disposed
      end

      def render(num_frames, start_frame = 0, cache = {})
        cache_key = [object_id, start_frame, num_frames]
        return cache.fetch(cache_key).dup if cache.key?(cache_key)

        input_buffer = mix_sources(num_frames, start_frame, cache)
        output_buffer = process(input_buffer, num_frames, start_frame, cache)
        cache[cache_key] = output_buffer
        output_buffer.dup
      end

      protected

      def attach_source(source)
        return if @sources.include?(source)

        @sources << source
      end

      def detach_source(source)
        @sources.delete(source)
      end

      def attach_destination(destination)
        return if @destinations.include?(destination)

        @destinations << destination
        destination.attach_source(self)
      end

      def detach_destination(destination)
        return unless @destinations.delete(destination)

        destination.detach_source(self)
      end

      def detach_all_destinations
        @destinations.dup.each { |destination| detach_destination(destination) }
      end

      def mix_sources(num_frames, start_frame, cache)
        mixed = Array.new(num_frames, 0.0)

        @sources.each do |source|
          rendered = source.render(num_frames, start_frame, cache)
          num_frames.times do |index|
            mixed[index] += rendered[index]
          end
        end

        mixed
      end

      def process(input_buffer, _num_frames, _start_frame, _cache)
        input_buffer
      end
    end
  end
end
