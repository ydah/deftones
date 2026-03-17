# frozen_string_literal: true

module Deftones
  module Component
    class Envelope < Core::AudioNode
      STATES = %i[idle attack decay sustain release].freeze

      attr_accessor :attack, :decay, :sustain, :release
      attr_reader :state

      def initialize(attack: 0.01, decay: 0.1, sustain: 0.5, release: 1.0, context: Deftones.context)
        super(context: context)
        @attack = attack.to_f
        @decay = decay.to_f
        @sustain = sustain.to_f
        @release = release.to_f
        @state = :idle
        @events = []
        @current_value = 0.0
        @velocity = 1.0
        @stage_started_at = 0.0
        @stage_from_value = 0.0
      end

      def trigger_attack(time = nil, velocity = 1.0)
        schedule_event(:attack, resolve_time(time), velocity.to_f)
      end

      def trigger_release(time = nil)
        schedule_event(:release, resolve_time(time), nil)
      end

      def trigger_attack_release(duration, time = nil, velocity = 1.0)
        attack_time = resolve_time(time)
        trigger_attack(attack_time, velocity)
        trigger_release(attack_time + Deftones::Music::Time.parse(duration))
      end

      def active?
        @state != :idle || !@events.empty?
      end

      def idle?
        !active?
      end

      def multichannel_process?
        true
      end

      def process(input_block, num_frames, start_frame, _cache)
        values = Array.new(num_frames) do |index|
          time = sample_time(start_frame + index)
          consume_events(time)
          @current_value = envelope_value_at(time)
          @current_value
        end

        Core::AudioBlock.from_channel_data(
          input_block.channel_data.map do |channel|
            Array.new(num_frames) { |index| channel[index] * values[index] }
          end
        )
      end

      private

      def schedule_event(type, time, velocity)
        @events << { type: type, time: time, velocity: velocity }
        @events.sort_by! { |event| event[:time] }
        self
      end

      def consume_events(time)
        while @events.any? && @events.first[:time] <= time
          event = @events.shift

          case event[:type]
          when :attack
            @state = :attack
            @velocity = event[:velocity] || 1.0
            @stage_started_at = event[:time]
            @stage_from_value = @current_value
          when :release
            @state = :release
            @stage_started_at = event[:time]
            @stage_from_value = @current_value
          end
        end
      end

      def envelope_value_at(time)
        case @state
        when :idle
          0.0
        when :attack
          attack_value(time)
        when :decay
          decay_value(time)
        when :sustain
          @velocity * @sustain
        when :release
          release_value(time)
        else
          0.0
        end
      end

      def attack_value(time)
        return transition_to(:decay, @velocity, time) if @attack <= 0.0

        progress = (time - @stage_started_at) / @attack
        return transition_to(:decay, @velocity, @stage_started_at + @attack) if progress >= 1.0

        lerp(@stage_from_value, @velocity, progress)
      end

      def decay_value(time)
        sustain_level = @velocity * @sustain
        return transition_to(:sustain, sustain_level, time) if @decay <= 0.0

        progress = (time - @stage_started_at) / @decay
        return transition_to(:sustain, sustain_level, @stage_started_at + @decay) if progress >= 1.0

        lerp(@velocity, sustain_level, progress)
      end

      def release_value(time)
        return transition_to(:idle, 0.0, time) if @release <= 0.0

        progress = (time - @stage_started_at) / @release
        return transition_to(:idle, 0.0, @stage_started_at + @release) if progress >= 1.0

        lerp(@stage_from_value, 0.0, progress)
      end

      def transition_to(next_state, value, time)
        @state = next_state
        @stage_started_at = time
        @stage_from_value = value
        @current_value = value
        value
      end

      def lerp(from, to, progress)
        from + ((to - from) * progress.clamp(0.0, 1.0))
      end

      def resolve_time(time)
        return context.current_time if time.nil?

        Deftones::Music::Time.parse(time)
      end

      def sample_time(frame_index)
        frame_index.to_f / context.sample_rate
      end
    end
  end
end
