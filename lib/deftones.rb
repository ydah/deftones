# frozen_string_literal: true

begin
  require "portaudio"
rescue LoadError
  nil
end

begin
  require "wavify/errors"
  require "wavify/core/format"
  require "wavify/core/duration"
  require "wavify/core/sample_buffer"
  require "wavify/codecs/base"
  require "wavify/codecs/wav"
rescue LoadError
  nil
end

require_relative "deftones/version"
require_relative "deftones/portaudio_support"
require_relative "deftones/context"
require_relative "deftones/offline_context"
require_relative "deftones/dsp/helpers"
require_relative "deftones/dsp/delay_line"
require_relative "deftones/dsp/biquad"
require_relative "deftones/event/callback_behavior"
require_relative "deftones/event/transport"
require_relative "deftones/event/tone_event"
require_relative "deftones/event/loop"
require_relative "deftones/event/part"
require_relative "deftones/event/sequence"
require_relative "deftones/event/pattern"
require_relative "deftones/music/note"
require_relative "deftones/music/frequency"
require_relative "deftones/music/midi"
require_relative "deftones/music/time"
require_relative "deftones/music/transport_time"
require_relative "deftones/music/ticks"
require_relative "deftones/destination"
require_relative "deftones/draw"
require_relative "deftones/listener"
require_relative "deftones/io/buffer"
require_relative "deftones/io/buffers"
require_relative "deftones/io/recorder"
require_relative "deftones/core/audio_node"
require_relative "deftones/core/signal_operator_methods"
require_relative "deftones/core/source"
require_relative "deftones/core/signal"
require_relative "deftones/core/synced_signal"
require_relative "deftones/core/computed_signal"
require_relative "deftones/core/signal_operators"
require_relative "deftones/core/signal_shapers"
require_relative "deftones/core/gain"
require_relative "deftones/core/param"
require_relative "deftones/core/instrument"
require_relative "deftones/core/effect"
require_relative "deftones/source/oscillator"
require_relative "deftones/source/noise"
require_relative "deftones/source/user_media"
require_relative "deftones/source/pulse_oscillator"
require_relative "deftones/source/fm_oscillator"
require_relative "deftones/source/am_oscillator"
require_relative "deftones/source/fat_oscillator"
require_relative "deftones/source/pwm_oscillator"
require_relative "deftones/source/omni_oscillator"
require_relative "deftones/source/karplus_strong"
require_relative "deftones/source/player"
require_relative "deftones/source/players"
require_relative "deftones/source/grain_player"
require_relative "deftones/source/tone_buffer_source"
require_relative "deftones/source/tone_oscillator_node"
require_relative "deftones/component/envelope"
require_relative "deftones/component/amplitude_envelope"
require_relative "deftones/component/frequency_envelope"
require_relative "deftones/component/filter"
require_relative "deftones/component/biquad_filter"
require_relative "deftones/component/follower"
require_relative "deftones/component/feedback_comb_filter"
require_relative "deftones/component/lfo"
require_relative "deftones/component/lowpass_comb_filter"
require_relative "deftones/component/one_pole_filter"
require_relative "deftones/component/volume"
require_relative "deftones/component/panner"
require_relative "deftones/component/panner3d"
require_relative "deftones/component/convolver"
require_relative "deftones/component/pan_vol"
require_relative "deftones/component/solo"
require_relative "deftones/component/channel"
require_relative "deftones/component/cross_fade"
require_relative "deftones/component/merge"
require_relative "deftones/component/mid_side_compressor"
require_relative "deftones/component/mid_side_merge"
require_relative "deftones/component/mid_side_split"
require_relative "deftones/component/mono"
require_relative "deftones/component/multiband_compressor"
require_relative "deftones/component/multiband_split"
require_relative "deftones/component/split"
require_relative "deftones/component/eq3"
require_relative "deftones/component/compressor"
require_relative "deftones/component/limiter"
require_relative "deftones/component/gate"
require_relative "deftones/analysis/fft"
require_relative "deftones/analysis/waveform"
require_relative "deftones/analysis/analyser"
require_relative "deftones/analysis/meter"
require_relative "deftones/analysis/dc_meter"
require_relative "deftones/effect/distortion"
require_relative "deftones/effect/bit_crusher"
require_relative "deftones/effect/chebyshev"
require_relative "deftones/effect/feedback_delay"
require_relative "deftones/effect/ping_pong_delay"
require_relative "deftones/effect/reverb"
require_relative "deftones/effect/freeverb"
require_relative "deftones/effect/jc_reverb"
require_relative "deftones/effect/chorus"
require_relative "deftones/effect/phaser"
require_relative "deftones/effect/tremolo"
require_relative "deftones/effect/vibrato"
require_relative "deftones/effect/auto_filter"
require_relative "deftones/effect/auto_panner"
require_relative "deftones/effect/auto_wah"
require_relative "deftones/effect/frequency_shifter"
require_relative "deftones/effect/pitch_shift"
require_relative "deftones/effect/stereo_widener"
require_relative "deftones/instrument/synth"
require_relative "deftones/instrument/mono_synth"
require_relative "deftones/instrument/fm_synth"
require_relative "deftones/instrument/am_synth"
require_relative "deftones/instrument/duo_synth"
require_relative "deftones/instrument/noise_synth"
require_relative "deftones/instrument/pluck_synth"
require_relative "deftones/instrument/membrane_synth"
require_relative "deftones/instrument/metal_synth"
require_relative "deftones/instrument/sampler"
require_relative "deftones/instrument/poly_synth"

module Deftones
  class Error < StandardError; end
  class MissingRealtimeBackendError < Error; end

  class << self
    def context
      @context ||= Context.new
    end

    def start(use_realtime: true)
      context.start(use_realtime: use_realtime)
    end

    def output
      context.output
    end

    def destination
      Destination.node(context: context)
    end

    def get_destination
      destination
    end

    def draw
      Draw.instance
    end

    def get_draw
      draw
    end

    def listener
      @listener ||= Listener.new
    end

    def get_listener
      listener
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

    def render_to_file(path, duration:, format: nil, **options, &block)
      ctx = OfflineContext.new(duration: duration, **options)
      block&.call(ctx)
      ctx.render_to_file(path, format: format)
    end

    def loaded
      true
    end

    def reset!
      @context&.stop
      @context = nil
      Destination.reset!
      Draw.reset!
      @listener = nil
      @transport = nil
    end

    def portaudio_available?
      Deftones::PortAudioSupport.available?
    end

    def wavify_available?
      !!defined?(Wavify::Core::SampleBuffer) && !!defined?(Wavify::Codecs::Wav)
    end

    def supported?
      true
    end

    def connect_series(*nodes)
      nodes.each_cons(2) { |source, destination_node| source.connect(destination_node) }
      nodes.last
    end

    def connect_signal(source, destination_node)
      source.connect(destination_node)
      destination_node
    end

    def fan_in(destination_node, *sources)
      sources.each { |source| source.connect(destination_node) }
      destination_node
    end

    def db_to_gain(value)
      10.0**(value.to_f / 20.0)
    end

    def gain_to_db(value)
      gain = value.to_f
      return -Float::INFINITY if gain <= 0.0

      20.0 * Math.log10(gain)
    end

    def ftom(value)
      Frequency.to_midi(value)
    end

    def mtof(value)
      Note.to_frequency(Note.from_midi(value))
    end

    alias wavefile_available? wavify_available?
    alias supported supported?
    alias dbToGain db_to_gain
    alias gainToDb gain_to_db
    alias getDestination get_destination
    alias getDraw get_draw
    alias getListener get_listener
    alias connectSeries connect_series
    alias connectSignal connect_signal
    alias fanIn fan_in
  end

  AudioNode = Core::AudioNode
  Effect = Core::Effect
  Gain = Core::Gain
  Param = Core::Param
  Signal = Core::Signal
  SyncedSignal = Core::SyncedSignal
  Abs = Core::Abs
  Add = Core::Add
  AudioToGain = Core::AudioToGain
  EqualPowerGain = Core::EqualPowerGain
  GainToAudio = Core::GainToAudio
  GreaterThan = Core::GreaterThan
  GreaterThanZero = Core::GreaterThanZero
  Modulo = Core::Modulo
  Multiply = Core::Multiply
  Negate = Core::Negate
  Normalize = Core::Normalize
  Pow = Core::Pow
  Scale = Core::Scale
  ScaleExp = Core::ScaleExp
  Subtract = Core::Subtract
  WaveShaper = Core::WaveShaper
  Zero = Core::Zero
  Oscillator = Source::Oscillator
  Noise = Source::Noise
  UserMedia = Source::UserMedia
  PulseOscillator = Source::PulseOscillator
  FMOscillator = Source::FMOscillator
  AMOscillator = Source::AMOscillator
  FatOscillator = Source::FatOscillator
  PWMOscillator = Source::PWMOscillator
  OmniOscillator = Source::OmniOscillator
  Player = Source::Player
  Players = Source::Players
  GrainPlayer = Source::GrainPlayer
  ToneBufferSource = Source::ToneBufferSource
  ToneOscillatorNode = Source::ToneOscillatorNode
  Envelope = Component::Envelope
  AmplitudeEnvelope = Component::AmplitudeEnvelope
  FrequencyEnvelope = Component::FrequencyEnvelope
  BiquadFilter = Component::BiquadFilter
  FeedbackCombFilter = Component::FeedbackCombFilter
  Filter = Component::Filter
  Follower = Component::Follower
  LFO = Component::LFO
  LowpassCombFilter = Component::LowpassCombFilter
  OnePoleFilter = Component::OnePoleFilter
  Volume = Component::Volume
  Panner = Component::Panner
  Panner3D = Component::Panner3D
  Convolver = Component::Convolver
  PanVol = Component::PanVol
  Solo = Component::Solo
  Channel = Component::Channel
  CrossFade = Component::CrossFade
  Merge = Component::Merge
  MidSideCompressor = Component::MidSideCompressor
  MidSideMerge = Component::MidSideMerge
  MidSideSplit = Component::MidSideSplit
  Mono = Component::Mono
  MultibandCompressor = Component::MultibandCompressor
  MultibandSplit = Component::MultibandSplit
  Split = Component::Split
  EQ3 = Component::EQ3
  Compressor = Component::Compressor
  Limiter = Component::Limiter
  Gate = Component::Gate
  Analyser = Analysis::Analyser
  Meter = Analysis::Meter
  FFT = Analysis::FFT
  Waveform = Analysis::Waveform
  DCMeter = Analysis::DCMeter
  Distortion = Effects::Distortion
  BitCrusher = Effects::BitCrusher
  Chebyshev = Effects::Chebyshev
  FeedbackDelay = Effects::FeedbackDelay
  PingPongDelay = Effects::PingPongDelay
  Reverb = Effects::Reverb
  Freeverb = Effects::Freeverb
  JCReverb = Effects::JCReverb
  Chorus = Effects::Chorus
  Phaser = Effects::Phaser
  Tremolo = Effects::Tremolo
  Vibrato = Effects::Vibrato
  AutoFilter = Effects::AutoFilter
  AutoPanner = Effects::AutoPanner
  AutoWah = Effects::AutoWah
  FrequencyShifter = Effects::FrequencyShifter
  PitchShift = Effects::PitchShift
  StereoWidener = Effects::StereoWidener
  Synth = Instrument::Synth
  MonoSynth = Instrument::MonoSynth
  FMSynth = Instrument::FMSynth
  AMSynth = Instrument::AMSynth
  DuoSynth = Instrument::DuoSynth
  NoiseSynth = Instrument::NoiseSynth
  PluckSynth = Instrument::PluckSynth
  MembraneSynth = Instrument::MembraneSynth
  MetalSynth = Instrument::MetalSynth
  Sampler = Instrument::Sampler
  PolySynth = Instrument::PolySynth
  Buffer = IO::Buffer
  Buffers = IO::Buffers
  ToneAudioBuffer = IO::Buffer
  ToneAudioBuffers = IO::Buffers
  Recorder = IO::Recorder
  Note = Music::Note
  Frequency = Music::Frequency
  Midi = Music::Midi
  Ticks = Music::Ticks
  Time = Music::Time
  TransportTime = Music::TransportTime
  Transport = Event::Transport
  ToneEvent = Event::ToneEvent
  Loop = Event::Loop
  Part = Event::Part
  Sequence = Event::Sequence
  Pattern = Event::Pattern
end
