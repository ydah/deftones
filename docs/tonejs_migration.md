# Tone.js Migration Guide

This project follows Tone.js concepts, but the API is adapted to Ruby.

## Quick mappings

- `new Tone.Synth().toDestination()` -> `Deftones::Synth.new.to_output`
- `triggerAttackRelease("C4", "8n")` -> `play("C4", duration: "8n")`
- `connect(node)` -> `>>` or `connect`
- `Tone.Transport.bpm.value = 140` -> `Deftones.transport.bpm = 140`
- `new Tone.Sequence(...).start(0)` -> `Deftones::Sequence.new(...).start(0)`
- `Tone.Offline(...)` -> `Deftones.render` or `Deftones.render_to_file`

## Time values

- Tone.js strings like `"4n"`, `"8t"`, `"1m"`, and `"2:1:0"` work the same way.
- Ruby symbols are also accepted for common note values such as `:quarter` and `:eighth`.

## Effects and routing

- Tone.js node chains map directly to `>>`.
- Use `to_output` instead of `toDestination`.
- `CrossFade`, `Merge`, and `Split` exist as lower-level routing helpers when you need explicit graph control.

## Realtime and offline usage

- Realtime output starts lazily when a node connects to `Deftones.output` or calls `to_output`.
- Offline rendering is deterministic and recommended for tests and file export.
- `render_to_file("song.mp3", duration: 5.0)` exports MP3 when an encoder backend is installed.
