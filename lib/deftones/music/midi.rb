# frozen_string_literal: true

begin
  require "unimidi"
rescue LoadError
  nil
end

module Deftones
  module Music
    class Midi
      class << self
        def available?
          !!defined?(UniMIDI)
        end

        def input_devices
          return [] unless available?

          UniMIDI::Input.all
        end

        def output_devices
          return [] unless available?

          UniMIDI::Output.all
        end
      end
    end
  end
end
