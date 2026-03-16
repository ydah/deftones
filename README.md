# Deftones

Deftones is a Ruby audio synthesis library with a flexible node graph, oscillator and synth variants, effects, transport/event scheduling, sample playback, analysis utilities, offline rendering, and an optional PortAudio-backed realtime context.

## Features

- Pull-based `AudioNode` graph with `connect`, `>>`, `chain`, `fan`, and `to_output`
- `Context`, `OfflineContext`, `Destination`, `Draw`, `Listener`, `Emitter`, `Clock`, and `Delay`
- `Signal` automation, note/frequency/time wrappers, MIDI device I/O wrappers, and compatibility top-level helpers
- `Param`, `ToneAudioNode`, `UserMedia`, `CrossFade`, `Merge`, and `Split` for lower-level graph construction
- Oscillators: basic, pulse, PWM, FM, AM, fat, omni, noise
- Instruments: `Synth`, `MonoSynth`, `FMSynth`, `AMSynth`, `DuoSynth`, `NoiseSynth`, `PluckSynth`, `MembraneSynth`, `MetalSynth`, `PolySynth`, `Sampler`
- Effects: distortion, crusher, chebyshev, delays, reverbs, chorus, phaser, tremolo, vibrato, auto-filter, auto-panner, auto-wah, shifter, pitch shift, widener
- Filters, EQ, compressor, limiter, gate, convolution, comb, mid/side, multiband, and channel utilities
- Transport, loops, parts, sequences, and patterns
- Player, players, grain player, `ToneBufferSource`, `ToneOscillatorNode`, recorder, `ToneAudioBuffer`, `ToneAudioBuffers`, analyser, meter, FFT, waveform, DC meter
- Standalone sources and modulation effects can be scheduled against the transport with `sync` / `start` / `stop`
- Instruments expose `volume`, `mute`, camelCase trigger helpers, `PolySynth#releaseAll`, and `Sampler#add` / `get` / `has?`

## Installation

```bash
bundle add deftones
```

For realtime output on macOS:

```bash
brew install portaudio
```

For development in this repository:

```bash
bundle install
bundle exec rspec
bundle exec yard doc
```

## Quick Start

### Offline synth render

```ruby
require "deftones"

Deftones.render_to_file("output.wav", duration: 1.0) do |context|
  synth = Deftones::Synth.new(context: context, type: :sawtooth).to_output
  synth.play("C4", duration: "8n", at: 0.0)
  synth.play("E4", duration: "8n", at: "4n")
  synth.play("G4", duration: "8n", at: "2n")
end

Deftones.render_to_file("output.mp3", duration: 1.0) do |context|
  Deftones::Synth.new(context: context).to_output.play("A4", duration: "4n")
end
```

### Transport + sequence

```ruby
require "deftones"

context = Deftones::OfflineContext.new(duration: 1.0)
synth = Deftones::MonoSynth.new(context: context).to_output

Deftones.transport.bpm = 120
Deftones::Sequence.new(notes: ["C4", "E4", "G4", "B4"], subdivision: "8n", loop: false) do |time, note|
  synth.play(note, duration: "16n", at: time)
end.start(0)

context.render.save("sequence.wav")
```

### Sample playback

```ruby
require "deftones"

context = Deftones::OfflineContext.new(duration: 0.5)
player = Deftones::Player.new(buffer: "kick.wav", context: context)
player >> context.output
player.start(0.0)
context.render.save("player.wav")
```

### Buffer collections and MIDI output

```ruby
require "deftones"

buffers = Deftones::Buffers.new(kick: "kick.wav", snare: "snare.ogg")
Deftones::Midi.note_on("C4", velocity: 100, device: "IAC Driver Bus 1")
```

### Realtime context and live input

```ruby
require "deftones"

mic = Deftones::UserMedia.new(live: true).to_output.start
sleep 2
mic.stop
```

### Compatibility helpers

```ruby
require "deftones"

Deftones.start(use_realtime: false)
Deftones.destination.volume.value = -6

clock = Deftones::Clock.new(frequency: 2)
time = Deftones.time("4n")
freq = Deftones.frequency("A4")

puts [clock.nextTickTime(0.25), time.to_seconds, freq.to_hz].inspect
```

### Synced sources and modulation effects

```ruby
require "deftones"

context = Deftones::OfflineContext.new(duration: 0.6, sample_rate: 100)
source = Deftones::Oscillator.new(frequency: 5, context: context).sync
effect = Deftones::Tremolo.new(frequency: 5, depth: 1.0, context: context).sync

Deftones.transport.bpm = 120
source >> effect >> context.output
source.start("8n")
effect.start("8n")
source.stop("4n")
effect.stop("4n")

context.render.save("synced.wav")
```

## Main API Surface

### Core and globals

`Context`, `OfflineContext`, `BaseContext`, `AudioNode`, `ToneAudioNode`, `Gain`, `Param`, `Signal`, `SyncedSignal`, `Emitter`, `Clock`, `Delay`, `Destination`, `Draw`, `Listener`

Top-level helpers include `start`, `loaded`, `supported`, `getContext`, `setContext`, `getDestination`, `getDraw`, `getListener`, `getTransport`, `connect`, `disconnect`, `connectSeries`, `connectSignal`, `fanIn`, `dbToGain`, `gainToDb`, `intervalToFrequencyRatio`, `frequency`, `midi`, `time`, `ticks`, and `transportTime`.

Every `AudioNode` also exposes shared helpers such as `toDestination`, `toMaster`, `toSeconds`, `toTicks`, `toFrequency`, `toMidi`, `set`, `get`, and `toString`.

`Signal` and `Param` expose automation helpers including `setValueCurveAtTime`, `setTargetAtTime`, `linearRampToValueAtTime`, `exponentialRampToValueAtTime`, `cancelAndHoldAtTime`, `targetRampTo`, and `getValueAtTime`.

### Sources

`Oscillator`, `Noise`, `UserMedia`, `PulseOscillator`, `FMOscillator`, `AMOscillator`, `FatOscillator`, `PWMOscillator`, `OmniOscillator`, `Player`, `Players`, `GrainPlayer`, `ToneBufferSource`, `ToneOscillatorNode`

### Instruments

`Synth`, `MonoSynth`, `FMSynth`, `AMSynth`, `DuoSynth`, `NoiseSynth`, `PluckSynth`, `MembraneSynth`, `MetalSynth`, `PolySynth`, `Sampler`

Common helpers include `volume`, `mute`, `set`, `get`, `triggerAttack`, `triggerRelease`, and `triggerAttackRelease`.

### Effects and Dynamics

`Distortion`, `BitCrusher`, `Chebyshev`, `FeedbackDelay`, `PingPongDelay`, `Reverb`, `Freeverb`, `JCReverb`, `Chorus`, `Phaser`, `Tremolo`, `Vibrato`, `AutoFilter`, `AutoPanner`, `AutoWah`, `FrequencyShifter`, `PitchShift`, `StereoWidener`, `Filter`, `EQ3`, `Compressor`, `Limiter`, `Gate`

LFO-based effects also support `start`, `stop`, `restart`, `state`, `sync`, and `unsync`.

### Scheduling

`Transport`, `ToneEvent`, `Loop`, `Part`, `Sequence`, `Pattern`

### Analysis and Utilities

`Analyser`, `Meter`, `FFT`, `Waveform`, `DCMeter`, `Volume`, `Panner`, `Panner3D`, `PanVol`, `Solo`, `Channel`, `CrossFade`, `Merge`, `Split`, `Param`, `Buffer`, `Buffers`, `ToneAudioBuffer`, `ToneAudioBuffers`, `Recorder`, `Note`, `Frequency`, `Time`, `Ticks`, `TransportTime`, `Midi`

Alias constants matching the docs are also available: `FrequencyClass`, `MidiClass`, `TimeClass`, `TicksClass`, and `TransportTimeClass`.

## Examples

Runnable examples live in [`examples/`](examples).

Release history lives in [`CHANGELOG.md`](CHANGELOG.md).

## Notes

- Offline rendering is the most stable path and is fully covered by specs.
- The default realtime context starts lazily when you connect to output.
- Realtime output and `UserMedia.new(live: true)` use the `portaudio` gem when available.
- WAV I/O uses the `wavify` gem, and MP3/OGG loading falls back to `ffmpeg` when installed.
- `render_to_file` and `Buffer#save` can export WAV, MP3, and OGG when an encoder backend is installed.
- MIDI device discovery and I/O wrappers use `unimidi` when available.
- Unit-style classes map to Ruby wrappers where possible; `Frequency`, `Time`, `Ticks`, and `TransportTime` are available directly, while `Midi` also keeps device I/O class methods.
- Unit wrappers expose conversion helpers such as `toNotation`, `toMilliseconds`, `toSamples`, `transpose`, `harmonize`, `quantize`, `dispose`, and `toString`.

## License

Released under the MIT License. See [LICENSE.txt](LICENSE.txt).
