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
        raise ArgumentError, "destination is required" if destination.nil?

        source_node = output_for_connection(output_index)
        destination_node = destination_for_connection(destination, input_index)
        validate_connectable!(source_node, destination_node)
        raise ArgumentError, "connection would create a cycle" if destination_node.send(:reaches_node?, source_node)

        source_node.attach_destination(destination_node)
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

      def inputs
        @sources.dup
      end

      def outputs
        @destinations.dup
      end

      def connected?(destination = nil)
        return @destinations.any? if destination.nil?

        destination_node = destination.respond_to?(:input) ? destination.input : destination
        @destinations.include?(destination_node)
      end

      def to_output
        connect(context.output)
        self
      end

      def to_destination
        to_output
      end

      def to_master
        to_destination
      end

      def now
        context.current_time
      end

      def immediate
        now
      end

      def to_seconds(time = nil)
        return context.current_time if time.nil?

        Deftones::Music::Time.parse(time)
      end

      def to_ticks(time = nil)
        return Deftones.transport.ticks if time.nil?

        Deftones.transport.seconds_to_ticks(to_seconds(time))
      end

      def to_frequency(value)
        Deftones::Music::Frequency.parse(value)
      end

      def to_midi(value)
        Deftones::Music::Midi.parse(value)
      end

      def sample_time
        1.0 / context.sample_rate
      end

      def block_time
        context.buffer_size.to_f / context.sample_rate
      end

      def channel_count
        context.channels
      end

      def channel_count_mode
        "max"
      end

      def channel_interpretation
        "speakers"
      end

      def number_of_inputs
        1
      end

      def number_of_outputs
        1
      end

      def set(strict: false, **params)
        unknown = params.keys.reject { |key| respond_to?(:"#{key}=") }
        raise ArgumentError, "Unknown parameter(s): #{unknown.join(', ')}" if strict && unknown.any?

        params.each do |key, value|
          writer = :"#{key}="
          public_send(writer, value) if respond_to?(writer)
        end
        self
      end

      def get(*keys, strict: false)
        unknown = []
        values = keys.flatten.each_with_object({}) do |key, collected|
          reader = key.to_sym
          if respond_to?(reader)
            collected[reader] = public_send(reader)
          else
            unknown << reader
          end
        end
        raise ArgumentError, "Unknown parameter(s): #{unknown.join(', ')}" if strict && unknown.any?

        values
      end

      def name
        self.class.name.split("::").last
      end

      def to_s
        name
      end

      alias toDestination to_destination
      alias toMaster to_master
      alias toSeconds to_seconds
      alias toTicks to_ticks
      alias toFrequency to_frequency
      alias toMidi to_midi
      alias sampleTime sample_time
      alias blockTime block_time
      alias channelCount channel_count
      alias channelCountMode channel_count_mode
      alias channelInterpretation channel_interpretation
      alias numberOfInputs number_of_inputs
      alias numberOfOutputs number_of_outputs
      alias connected connected?
      alias toString to_s

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
        render_block(num_frames, start_frame, cache).mono
      end

      protected

      def output_for_index(index)
        raise_connection_index_error!(:output_index, index, number_of_outputs) unless index.zero?

        output
      end

      def input_for_index(index)
        raise_connection_index_error!(:input_index, index, number_of_inputs) unless index.zero?

        input
      end

      def render_block(num_frames, start_frame = 0, cache = {})
        raise Deftones::Error, "cannot render disposed node: #{name}" if disposed?

        cache_key = [object_id, :block, start_frame, num_frames]
        return cache.fetch(cache_key).dup if cache.key?(cache_key)

        output_block = if uses_legacy_render_for_block?
                         normalize_output_block(render(num_frames, start_frame, cache), num_frames, 1)
                       else
                         input_block = mix_source_blocks(num_frames, start_frame, cache)
                         if multichannel_process?
                           normalize_output_block(process(input_block, num_frames, start_frame, cache), num_frames, input_block.channels)
                         else
                           mono_output = process(input_block.mono, num_frames, start_frame, cache)
                           normalize_output_block(mono_output, num_frames, [input_block.channels, default_output_channels].max)
                         end
                       end

        cache[cache_key] = output_block
        output_block.dup
      end

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

      def mix_source_blocks(num_frames, start_frame, cache)
        blocks = @sources.map { |source| source.send(:render_block, num_frames, start_frame, cache) }
        output_channels = blocks.map(&:channels).max || default_input_channels
        mixed = AudioBlock.silent(num_frames, output_channels)
        blocks.each { |block| mixed.mix!(block) }
        mixed
      end

      def normalize_output_block(output, num_frames, channels)
        return output.dup if output.is_a?(AudioBlock)

        AudioBlock.from_mono(output, channels: channels)
      end

      def process(input_buffer, _num_frames, _start_frame, _cache)
        input_buffer
      end

      def uses_legacy_render_for_block?
        self.class.instance_method(:render).owner != AudioNode
      end

      def multichannel_process?
        false
      end

      def default_input_channels
        1
      end

      def default_output_channels
        default_input_channels
      end

      def reaches_node?(target, visited = {})
        return true if equal?(target)
        return false if visited[object_id]

        visited[object_id] = true
        @destinations.any? { |destination| destination.send(:reaches_node?, target, visited) }
      end

      def raise_connection_index_error!(name, index, count)
        raise ArgumentError, "#{name} #{index} is out of range for #{count} #{count == 1 ? 'port' : 'ports'}"
      end

      private

      def output_for_connection(index)
        normalized_index = normalize_connection_index(index, :output_index)
        output_for_index(normalized_index)
      end

      def destination_for_connection(destination, index)
        normalized_index = normalize_connection_index(index, :input_index)
        if destination.respond_to?(:input_for_index)
          destination.input_for_index(normalized_index)
        else
          destination_node = destination.respond_to?(:input) ? destination.input : destination
          validate_connection_index!(normalized_index, destination_node.number_of_inputs, :input_index)
          destination_node
        end
      end

      def normalize_connection_index(index, name)
        Integer(index).tap do |normalized|
          raise ArgumentError, "#{name} must be greater than or equal to 0" if normalized.negative?
        end
      rescue ArgumentError, TypeError
        raise ArgumentError, "#{name} must be an integer"
      end

      def validate_connection_index!(index, count, name)
        raise_connection_index_error!(name, index, count) if index >= count
      end

      def validate_connectable!(source_node, destination_node)
        raise Deftones::Error, "cannot connect disposed source node" if source_node.disposed?
        raise Deftones::Error, "cannot connect disposed destination node" if destination_node.disposed?
      end
    end
  end
end
