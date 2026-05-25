# frozen_string_literal: true

module Deftones
  module Instrument
    class PolySynth < Core::Instrument
      VOICE_STEALING_POLICIES = %i[oldest newest quietest released_first].freeze
      RETRIGGER_POLICIES = %i[restart ignore].freeze

      attr_reader :voice_pool, :voice_stealing, :retrigger

      def initialize(voice_class = Synth, voices: 8, voice_stealing: :oldest, retrigger: :restart,
                     context: Deftones.context, **voice_options)
        super(context: context)
        @voice_class = voice_class
        @voice_pool = Array.new(voices) { @voice_class.new(context: context, **voice_options) }
        @voice_pool.each { |voice| voice >> @output }
        @voice_stealing = normalize_voice_stealing(voice_stealing)
        @retrigger = normalize_retrigger(retrigger)
        @active_voices = {}
      end

      def play(notes, duration: "8n", at: nil, velocity: 1.0)
        scheduled_time = resolve_time(at)

        Array(notes).compact.each do |note|
          trigger_attack(note, scheduled_time, velocity)
        end

        release_time = scheduled_time + Deftones::Music::Time.parse(duration)
        Array(notes).compact.each do |note|
          trigger_release(note, release_time)
        end

        self
      end

      def trigger_attack(note, time = nil, velocity = 1.0)
        scheduled_time = resolve_time(time)
        return self if @active_voices.key?(note) && @retrigger == :ignore

        voice = allocate_voice(note, scheduled_time)
        @active_voices.delete(note)
        @active_voices[note] = {
          voice: voice,
          attacked_at: scheduled_time,
          released_at: nil,
          velocity: velocity.to_f
        }
        voice.trigger_attack(note, scheduled_time, velocity)
        self
      end

      def trigger_release(note, time = nil)
        entry = @active_voices[note]
        return self unless entry

        scheduled_time = resolve_time(time)
        entry[:released_at] = scheduled_time
        entry[:voice].trigger_release(scheduled_time)
        self
      end

      def set(strict: false, **params)
        unknown = params.keys.reject { |key| @voice_pool.all? { |voice| voice.respond_to?(:"#{key}=") } }
        raise ArgumentError, "Unknown parameter(s): #{unknown.join(', ')}" if strict && unknown.any?

        @voice_pool.each do |voice|
          params.each do |key, value|
            writer = :"#{key}="
            voice.public_send(writer, value) if voice.respond_to?(writer)
          end
        end
        self
      end

      def release_all(time = nil)
        scheduled_time = resolve_time(time)
        @active_voices.each_value { |entry| entry[:voice].trigger_release(scheduled_time) }
        @active_voices.clear
        self
      end

      def max_polyphony
        @voice_pool.length
      end

      def loaded?
        true
      end

      alias loaded loaded?
      alias releaseAll release_all

      def active?
        @voice_pool.any?(&:active?)
      end

      def active_notes
        @active_voices.keys
      end

      def active_voice_count
        @active_voices.length
      end

      private

      def allocate_voice(note, time)
        cleanup_inactive_voices!
        return @active_voices[note][:voice] if @active_voices.key?(note)

        active_voice_ids = @active_voices.values.map { |entry| entry[:voice].object_id }
        available_voice = @voice_pool.find { |voice| !active_voice_ids.include?(voice.object_id) }
        return available_voice if available_voice

        stolen_note, stolen_entry = steal_voice_entry(time)
        @active_voices.delete(stolen_note)
        stolen_entry[:voice]
      end

      def steal_voice_entry(time)
        case @voice_stealing
        when :newest
          @active_voices.max_by { |_, entry| entry[:attacked_at] }
        when :quietest
          @active_voices.min_by { |_, entry| entry[:velocity] }
        when :released_first
          released = @active_voices.select { |_, entry| entry[:released_at] && entry[:released_at] <= time }
          return released.min_by { |_, entry| entry[:released_at] } if released.any?

          @active_voices.min_by { |_, entry| entry[:attacked_at] }
        else
          @active_voices.min_by { |_, entry| entry[:attacked_at] }
        end
      end

      def cleanup_inactive_voices!
        @active_voices.delete_if { |_, entry| entry[:released_at] && !entry[:voice].active? }
      end

      def normalize_voice_stealing(policy)
        normalized = policy.to_sym
        return normalized if VOICE_STEALING_POLICIES.include?(normalized)

        raise ArgumentError, "Unsupported voice stealing policy: #{policy}"
      end

      def normalize_retrigger(policy)
        normalized = policy.to_sym
        return normalized if RETRIGGER_POLICIES.include?(normalized)

        raise ArgumentError, "Unsupported retrigger policy: #{policy}"
      end

      def resolve_time(time)
        return context.current_time if time.nil?

        Deftones::Music::Time.parse(time)
      end
    end
  end
end
