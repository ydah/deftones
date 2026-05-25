# Changelog

## Unreleased

## 1.0.0 - 2026-05-25

- Expanded the public API surface across sources, instruments, effects, analysis, transport/event helpers, music-unit wrappers, and top-level compatibility helpers.
- Improved transport and event scheduling with context-scoped schedulers, scheduler-window offline rendering, tempo/state automation, richer pattern scheduling, and duplicate-safe realtime lookahead.
- Expanded sample, buffer, and render workflows with explicit resampling, interpolation modes, LUFS normalization, slice metadata, codec capability reporting, streamed compressed renders, codec path/format validation, and WAV bit depth/dither options.
- Added more synthesis and effects controls, including grain jitter/window options, selectable panner pan laws, reverb damping controls, compressor detector controls, nonlinear effect oversampling, sampler playback policies, instrument loaded state, and packed audio block access.
- Improved audio correctness and failure modes with stricter graph routing, voice state, source type, automation, param, event, codec, and music-value validation; clearer music value errors; feedback delay clamping; triangle oscillator fixes; filter state resets; and denormal DSP handling.
- Improved realtime and MIDI workflows with selectable realtime output devices, explicit realtime stream error policy, sample rate mismatch detection, metering diagnostics, MIDI device session handling, and MIDI-to-transport/target routing.
- Optional realtime, MIDI, and codec backends now load lazily and expose capability queries, so offline rendering can run without native realtime, MIDI, or codec dependencies.

## 0.1.0 - 2026-03-27

- Initial release.
