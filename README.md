# Deftones

Deftones is a Ruby audio synthesis library with a flexible node graph, oscillator and synth variants, effects, transport/event scheduling, sample playback, analysis utilities, offline rendering, and an optional PortAudio-backed realtime context.

## Features

- Pull-based `AudioNode` graph with `connect`, `>>`, `chain`, `fan`, and `to_output`
- `Context` and `OfflineContext`
- `Signal` automation, note/frequency/time helpers, MIDI device I/O wrappers
- `Param`, `UserMedia`, `CrossFade`, `Merge`, and `Split` for lower-level graph construction
- Oscillators: basic, pulse, PWM, FM, AM, fat, omni, noise
- Instruments: `Synth`, `MonoSynth`, `FMSynth`, `AMSynth`, `DuoSynth`, `NoiseSynth`, `PluckSynth`, `MembraneSynth`, `MetalSynth`, `PolySynth`, `Sampler`
- Effects: distortion, crusher, chebyshev, delays, reverbs, chorus, phaser, tremolo, vibrato, auto-filter, auto-panner, auto-wah, shifter, pitch shift, widener
- Filters, EQ, compressor, limiter, gate, channel utilities
- Transport, loops, parts, sequences, and patterns
- Player, grain player, recorder, buffer collections, analyser, meter, FFT, waveform, DC meter

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

## Main API Surface

### Sources

`Oscillator`, `Noise`, `UserMedia`, `PulseOscillator`, `FMOscillator`, `AMOscillator`, `FatOscillator`, `PWMOscillator`, `OmniOscillator`, `Player`, `Players`, `GrainPlayer`

### Instruments

`Synth`, `MonoSynth`, `FMSynth`, `AMSynth`, `DuoSynth`, `NoiseSynth`, `PluckSynth`, `MembraneSynth`, `MetalSynth`, `PolySynth`, `Sampler`

### Effects and Dynamics

`Distortion`, `BitCrusher`, `Chebyshev`, `FeedbackDelay`, `PingPongDelay`, `Reverb`, `Freeverb`, `JCReverb`, `Chorus`, `Phaser`, `Tremolo`, `Vibrato`, `AutoFilter`, `AutoPanner`, `AutoWah`, `FrequencyShifter`, `PitchShift`, `StereoWidener`, `Filter`, `EQ3`, `Compressor`, `Limiter`, `Gate`

### Scheduling

`Transport`, `ToneEvent`, `Loop`, `Part`, `Sequence`, `Pattern`

### Analysis and Utilities

`Analyser`, `Meter`, `FFT`, `Waveform`, `DCMeter`, `Volume`, `Panner`, `PanVol`, `Solo`, `Channel`, `CrossFade`, `Merge`, `Split`, `Param`, `Buffer`, `Buffers`, `Recorder`, `Note`, `Frequency`, `Time`, `Midi`

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

## License

Released under the MIT License. See [LICENSE.txt](LICENSE.txt).
