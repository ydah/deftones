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
end
