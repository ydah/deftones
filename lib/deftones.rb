# frozen_string_literal: true

begin
  require "ffi"
rescue LoadError
  nil
end

begin
  require "ffi-portaudio"
rescue LoadError
  nil
end

begin
  require "wavefile"
rescue LoadError
  nil
end

require_relative "deftones/version"
require_relative "deftones/context"
require_relative "deftones/offline_context"
require_relative "deftones/dsp/helpers"
require_relative "deftones/dsp/delay_line"
require_relative "deftones/dsp/biquad"
require_relative "deftones/event/transport"
require_relative "deftones/music/note"
require_relative "deftones/music/time"
require_relative "deftones/io/buffer"
require_relative "deftones/core/audio_node"
require_relative "deftones/core/source"
require_relative "deftones/core/signal"
require_relative "deftones/core/gain"
require_relative "deftones/core/instrument"
require_relative "deftones/core/effect"
require_relative "deftones/source/oscillator"
require_relative "deftones/source/noise"
require_relative "deftones/source/pulse_oscillator"
require_relative "deftones/source/fm_oscillator"
require_relative "deftones/source/am_oscillator"
require_relative "deftones/source/fat_oscillator"
require_relative "deftones/source/pwm_oscillator"
require_relative "deftones/source/omni_oscillator"
require_relative "deftones/source/karplus_strong"
require_relative "deftones/component/envelope"
require_relative "deftones/component/amplitude_envelope"
require_relative "deftones/component/frequency_envelope"
require_relative "deftones/component/filter"
require_relative "deftones/component/lfo"
require_relative "deftones/instrument/synth"
require_relative "deftones/instrument/mono_synth"
require_relative "deftones/instrument/fm_synth"
require_relative "deftones/instrument/am_synth"
require_relative "deftones/instrument/duo_synth"
require_relative "deftones/instrument/noise_synth"
require_relative "deftones/instrument/pluck_synth"
require_relative "deftones/instrument/membrane_synth"
require_relative "deftones/instrument/metal_synth"
require_relative "deftones/instrument/poly_synth"

module Deftones
  class Error < StandardError; end
  class MissingRealtimeBackendError < Error; end

  class << self
    def context
      @context ||= Context.new.start
    end

    def output
      context.output
    end

    def now
      context.current_time
    end

    def transport
      @transport ||= Event::Transport.new
    end

    def render(duration:, sample_rate: Context::DEFAULT_SAMPLE_RATE, channels: 2,
               buffer_size: Context::DEFAULT_BUFFER_SIZE, &block)
      ctx = OfflineContext.new(
        duration: duration,
        sample_rate: sample_rate,
        channels: channels,
        buffer_size: buffer_size
      )
      block&.call(ctx)
      ctx.render
    end

    def render_to_file(path, duration:, **options, &block)
      ctx = OfflineContext.new(duration: duration, **options)
      block&.call(ctx)
      ctx.render_to_file(path)
    end

    def reset!
      @context&.stop
      @context = nil
      @transport = nil
    end

    def portaudio_available?
      defined?(FFI::PortAudio)
    end

    def wavefile_available?
      defined?(WaveFile)
    end
  end

  AudioNode = Core::AudioNode
  Effect = Core::Effect
  Gain = Core::Gain
  Signal = Core::Signal
  Oscillator = Source::Oscillator
  Noise = Source::Noise
  PulseOscillator = Source::PulseOscillator
  FMOscillator = Source::FMOscillator
  AMOscillator = Source::AMOscillator
  FatOscillator = Source::FatOscillator
  PWMOscillator = Source::PWMOscillator
  OmniOscillator = Source::OmniOscillator
  Envelope = Component::Envelope
  AmplitudeEnvelope = Component::AmplitudeEnvelope
  FrequencyEnvelope = Component::FrequencyEnvelope
  Filter = Component::Filter
  LFO = Component::LFO
  Synth = Instrument::Synth
  MonoSynth = Instrument::MonoSynth
  FMSynth = Instrument::FMSynth
  AMSynth = Instrument::AMSynth
  DuoSynth = Instrument::DuoSynth
  NoiseSynth = Instrument::NoiseSynth
  PluckSynth = Instrument::PluckSynth
  MembraneSynth = Instrument::MembraneSynth
  MetalSynth = Instrument::MetalSynth
  PolySynth = Instrument::PolySynth
  Buffer = IO::Buffer
  Note = Music::Note
  Time = Music::Time
end
