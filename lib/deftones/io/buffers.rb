# frozen_string_literal: true

module Deftones
  module IO
    class Buffers
      include Enumerable

      class BulkLoadError < Deftones::Error
        attr_reader :errors

        def initialize(errors)
          @errors = errors
          super("Failed to load #{errors.length} buffer(s): #{errors.keys.join(', ')}")
        end
      end

      attr_reader :load_errors

      def initialize(buffers = {}, aggregate_errors: false, **keyword_buffers)
        @buffers = {}
        @load_errors = {}
        @disposed = false
        merge(buffers.merge(keyword_buffers), aggregate_errors: aggregate_errors)
      end

      def add(name, buffer)
        raise Deftones::Error, "cannot add buffer to disposed Buffers" if @disposed

        @buffers[key_for(name)] = normalize_buffer(buffer)
        self
      end

      def get(name)
        self[name]
      end

      def [](name)
        @buffers[key_for(name)]
      end

      def fetch(name)
        @buffers.fetch(key_for(name))
      end

      def has?(name)
        @buffers.key?(key_for(name))
      end

      def loaded?
        !@disposed
      end

      def each(&block)
        return enum_for(:each) unless block

        @buffers.each(&block)
      end

      def keys
        @buffers.keys
      end

      def to_h
        @buffers.dup
      end

      def merge(buffers, aggregate_errors: false)
        errors = {}
        buffers.each do |name, buffer|
          add(name, buffer)
        rescue StandardError => error
          raise unless aggregate_errors

          errors[key_for(name)] = error
        end
        @load_errors.merge!(errors)
        raise BulkLoadError, errors if errors.any?

        self
      end

      def dispose
        @buffers.clear
        @disposed = true
        self
      end

      alias loaded loaded?

      private

      def key_for(name)
        name.to_sym
      end

      def normalize_buffer(buffer)
        buffer.is_a?(Buffer) ? buffer : Buffer.load(buffer)
      end
    end
  end
end
