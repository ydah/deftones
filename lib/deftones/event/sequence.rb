# frozen_string_literal: true

module Deftones
  module Event
    class Sequence
      include Enumerable

      def initialize(notes:, subdivision: "4n", loop: true, transport: Deftones.transport, &callback)
        @notes = notes
        @subdivision = subdivision
        @loop = loop
        @transport = transport
        @callback = callback
        @event_id = nil
        @current_step = 0
      end

      def start(time = 0)
        @current_step = 0
        duration = @loop ? nil : (Deftones::Music::Time.parse(@subdivision) * (@notes.length - 1))
        @event_id = @transport.schedule_repeat(@subdivision, start_time: time, duration: duration) do |scheduled_time|
          process_step(scheduled_time)
          @current_step += 1
        end
        self
      end

      def stop(_time = nil)
        @transport.cancel(event_id: @event_id) if @event_id
        @event_id = nil
        self
      end

      def [](index)
        @notes[index]
      end

      def []=(index, value)
        @notes[index] = value
      end

      def each(&block)
        return enum_for(:each) unless block

        @notes.each(&block)
      end

      private

      def process_step(scheduled_time)
        note = @notes[@current_step % @notes.length]
        return if note.nil?

        if note.is_a?(Array)
          sub_duration = Deftones::Music::Time.parse(@subdivision) / note.length.to_f
          note.each_with_index do |nested_note, index|
            next if nested_note.nil?

            @callback.call(scheduled_time + (sub_duration * index), nested_note)
          end
        else
          @callback.call(scheduled_time, note)
        end
      end
    end
  end
end
