# frozen_string_literal: true

RSpec.describe "Transport and event scheduling" do
  it "tracks position and tempo" do
    transport = Deftones.transport
    transport.bpm = 120
    transport.position = "1:2:0"

    expect(transport.position).to eq("1:2:0")
    expect(Deftones::Time.parse("4n")).to eq(0.5)
  end

  it "materializes scheduled callbacks for tone events, loops, parts, sequences, and patterns" do
    transport = Deftones.transport
    transport.bpm = 120

    tone_event_calls = []
    Deftones::ToneEvent.new { |time| tone_event_calls << time }.start("4n")

    loop_calls = []
    Deftones::Loop.new(interval: "8n", iterations: 3) { |time| loop_calls << time }.start(0)

    part_calls = []
    Deftones::Part.new(
      events: [
        { time: 0.0, note: "C4" },
        { time: "8n", note: "E4" }
      ]
    ) { |time, event| part_calls << [time, event[:note]] }.start("4n")

    sequence_calls = []
    Deftones::Sequence.new(notes: ["C4", %w[E4 G4], nil], subdivision: "8n", loop: false) do |time, note|
      sequence_calls << [time, note]
    end.start(0)

    pattern_calls = []
    Deftones::Pattern.new(values: %w[C4 E4 G4], pattern: :up_down, interval: "8n") do |time, note|
      pattern_calls << [time, note]
    end.start(0)

    transport.prepare_render(1.0)

    expect(tone_event_calls).to eq([0.5])
    expect(loop_calls).to eq([0.0, 0.25, 0.5])
    expect(part_calls).to eq([[0.5, "C4"], [0.75, "E4"]])
    expect(sequence_calls).to eq([[0.0, "C4"], [0.25, "E4"], [0.375, "G4"]])
    expect(pattern_calls.first(5).map(&:last)).to eq(%w[C4 E4 G4 E4 C4])
  end

  it "drives scheduled notes into offline rendering" do
    context = Deftones::OfflineContext.new(duration: 0.5)
    synth = Deftones::Synth.new(context: context).to_output

    Deftones::Sequence.new(notes: %w[C4 E4 G4 C5], subdivision: "8n", loop: false) do |time, note|
      synth.play(note, duration: "16n", at: time)
    end.start(0)

    Deftones.transport.start
    buffer = context.render

    expect(buffer.peak).to be > 0.05
    expect(buffer.rms).to be > 0.01
  end

  it "exposes compatibility transport convenience helpers" do
    Deftones.reset!
    transport = Deftones.transport
    transport.bpm = 120
    transport.timeSignature = [4, 4]
    transport.swingSubdivision = "16n"
    transport.loop = true
    transport.setLoopPoints(0, "1m")
    transport.seconds = 1.0

    callbacks = []
    once_id = transport.scheduleOnce("4n") { |time| callbacks << [:once, time] }
    transport.scheduleRepeat("8n", start_time: "4n", duration: "4n") { |time| callbacks << [:repeat, time] }
    transport.clear(once_id)
    transport.prepare_render(1.0)

    expect(transport.time_signature).to eq([4, 4])
    expect(transport.swing_subdivision).to eq("16n")
    expect(transport.immediate).to eq(1.0)
    expect(transport.progress).to eq(0.5)
    expect(transport.nextSubdivision("4n")).to eq(1.5)
    expect(callbacks).to eq([[:repeat, 0.5], [:repeat, 0.75], [:repeat, 1.0]])

    transport.toggle(0)
    expect(transport.state).to eq(:started)
    transport.toggle(0.25)
    expect(transport.state).to eq(:paused)
  ensure
    Deftones.reset!
  end

  it "supports compatibility callback controls on scheduled events" do
    Deftones.reset!
    transport = Deftones.transport
    transport.bpm = 120

    tone_event_calls = []
    tone_event = Deftones::ToneEvent.new(probability: 0.0) { |time| tone_event_calls << time }.start("4n")

    loop_calls = []
    loop_event = Deftones::Loop.new(interval: "8n", iterations: 3, playback_rate: 2.0) do |time|
      loop_calls << time
    end.start(0)

    part_calls = []
    part = Deftones::Part.new(
      events: [
        { time: 0.0, note: "C4" },
        { time: "8n", note: "E4" }
      ],
      playback_rate: 2.0
    ) { |time, event| part_calls << [time, event[:note]] }.start(0)

    sequence_calls = []
    sequence = Deftones::Sequence.new(
      notes: %w[C4 E4],
      subdivision: "8n",
      mute: true
    ) { |time, note| sequence_calls << [time, note] }.start(0)

    pattern_calls = []
    pattern = Deftones::Pattern.new(
      values: %w[C4 E4],
      interval: "8n",
      playback_rate: 2.0
    ) { |time, note| pattern_calls << [time, note] }.start(0)

    transport.prepare_render(0.6)

    expect(tone_event.state).to eq(:started)
    expect(loop_event.state).to eq(:started)
    expect(part.state).to eq(:started)
    expect(sequence.state).to eq(:started)
    expect(pattern.state).to eq(:started)
    expect(tone_event_calls).to eq([])
    expect(loop_calls).to eq([0.0, 0.125, 0.25])
    expect(part_calls).to eq([[0.0, "C4"], [0.125, "E4"]])
    expect(sequence_calls).to eq([])
    expect(pattern_calls.first(4)).to eq([[0.0, "C4"], [0.125, "E4"], [0.25, "C4"], [0.375, "E4"]])

    pattern.cancel
    loop_event.dispose
    part.dispose
    sequence.dispose
    tone_event.cancel

    expect(pattern.state).to eq(:stopped)
    expect(loop_event.state).to eq(:stopped)
    expect(part.state).to eq(:stopped)
    expect(sequence.state).to eq(:stopped)
    expect(tone_event.state).to eq(:stopped)
  ensure
    Deftones.reset!
  end

  it "exposes camelCase aliases on event objects" do
    Deftones.reset!
    transport = Deftones.transport
    transport.bpm = 120

    calls = []
    tone_event = Deftones::ToneEvent.new(loop: true, loop_start: 0.0, loop_end: "8n") { |time| calls << time }
    tone_event.playbackRate = 2.0
    tone_event.loopStart = "8n"
    tone_event.loopEnd = "4n"
    tone_event.start(0)

    expect(tone_event.playbackRate).to eq(2.0)
    expect(tone_event.loopStart).to eq("8n")
    expect(tone_event.loopEnd).to eq("4n")
    expect(tone_event.mute?).to eq(false)

    transport.prepare_render(0.5)
    expect(calls).to eq([0.25, 0.375, 0.5])
  ensure
    Deftones.reset!
  end
end
