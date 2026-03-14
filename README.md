# Deftones

Deftones is a Ruby audio synthesis library inspired by Tone.js. This MVP focuses on the Phase 1 core described in `.idea`: a pull-based audio node graph, musical time/note parsing, basic oscillator synthesis, ADSR envelopes, polyphony, and offline WAV rendering.

## Features

- `Deftones::OfflineContext` for deterministic offline rendering
- `Deftones::AudioNode` graph with `connect`, `>>`, `chain`, `fan`, and `to_output`
- `Deftones::Signal` automation with scheduled values and ramps
- `Deftones::Oscillator` with `:sine`, `:square`, `:triangle`, and `:sawtooth`
- `Deftones::Envelope` / `Deftones::AmplitudeEnvelope`
- `Deftones::Synth` and `Deftones::PolySynth`
- `Deftones::Music::Note` and `Deftones::Music::Time`
- `Deftones.render` / `Deftones.render_to_file` convenience APIs

## Installation

Add the gem to your application:

```bash
bundle add deftones
```

For development in this repository:

```bash
bundle install
bundle exec rspec
```

## Quick Start

Render a short synth phrase directly to a WAV file:

```ruby
require "deftones"

Deftones.render_to_file("output.wav", duration: 1.0) do |context|
  synth = Deftones::Synth.new(
    context: context,
    type: :sawtooth,
    attack: 0.01,
    decay: 0.08,
    sustain: 0.35,
    release: 0.15
  ).to_output

  synth.play("C4", duration: "8n", at: 0.0)
  synth.play("E4", duration: "8n", at: "4n")
  synth.play("G4", duration: "8n", at: "2n")
end
```

Render in memory and inspect the resulting buffer:

```ruby
require "deftones"

buffer = Deftones.render(duration: 0.5) do |context|
  synth = Deftones::Synth.new(context: context, type: :triangle).to_output
  synth.play("A4", duration: 0.1)
end

puts buffer.frames
puts buffer.peak
puts buffer.rms
```

## Usage

### Node chaining

```ruby
require "deftones"

context = Deftones::OfflineContext.new(duration: 0.25)
oscillator = Deftones::Oscillator.new(type: :sine, frequency: 220, context: context)
gain = Deftones::Gain.new(gain: 0.25, context: context)

oscillator >> gain >> context.output
buffer = context.render
buffer.save("sine.wav")
```

### Polyphony

```ruby
require "deftones"

Deftones.render_to_file("chord.wav", duration: 0.5) do |context|
  synth = Deftones::PolySynth.new(Deftones::Synth, voices: 4, context: context).to_output
  synth.play(%w[C4 E4 G4 B4], duration: 0.15)
end
```

### Musical time

```ruby
Deftones.transport.bpm = 120

Deftones::Music::Time.parse("4n")   # => 0.5
Deftones::Music::Time.parse("8t")   # => 0.1666...
Deftones::Music::Time.parse("1:2:0") # => 3.0
```

## Examples

Runnable examples live in [`examples/`](examples).

## Development

After checking out the repo:

```bash
bundle install
bundle exec rspec
```

Generate API documentation with YARD:

```bash
bundle exec yard doc
```

## Notes

- The implemented MVP is currently offline-first. It renders deterministic buffers and WAV files without depending on a realtime audio device.
- `ffi` is included so the project can grow into the PortAudio-backed runtime described in the design docs.

## License

Released under the MIT License. See [LICENSE.txt](LICENSE.txt).
