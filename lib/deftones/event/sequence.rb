# frozen_string_literal: true

module Deftones
  module Event
    class Sequence
      include Enumerable
      include CallbackBehavior

      def initialize(notes:, subdivision: "4n", loop: true, transport: Deftones.transport,
                     probability: 1.0, humanize: false, mute: false, playback_rate: 1.0, &callback)
        @notes = notes
        @subdivision = subdivision
        @loop = loop
        @transport = transport
        @callback = callback
        @event_id = nil
        @current_step = 0
        initialize_callback_behavior(
          probability: probability,
          humanize: humanize,
          mute: mute,
          playback_rate: playback_rate
        )
      end

      def start(time = 0)
        @current_step = 0
        scaled_subdivision = callback_interval(@subdivision)
        duration = @loop ? nil : (scaled_subdivision * (@notes.length - 1))
        @event_id = @transport.schedule_repeat(scaled_subdivision, start_time: time, duration: duration) do |scheduled_time|
          process_step(scheduled_time)
          @current_step += 1
        end
        mark_started
        self
      end

      def stop(_time = nil)
        cancel
      end

      def cancel
        @transport.cancel(event_id: @event_id) if @event_id
        @event_id = nil
        mark_stopped
        self
      end

      def dispose
        cancel
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
        return unless callback_permitted?

        if note.is_a?(Array)
          sub_duration = callback_interval(@subdivision) / note.length.to_f
          note.each_with_index do |nested_note, index|
            next if nested_note.nil?

            @callback.call(humanized_time(scheduled_time + (sub_duration * index)), nested_note)
          end
        else
          @callback.call(humanized_time(scheduled_time), note)
        end
      end
    end
  end
end
