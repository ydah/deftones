# frozen_string_literal: true

RSpec.describe "Offline rendering" do
  it "renders a synth voice with an amplitude envelope" do
    context = Deftones::OfflineContext.new(duration: 0.25)
    synth = Deftones::Synth.new(
      context: context,
      type: :triangle,
      attack: 0.01,
      decay: 0.02,
      sustain: 0.4,
      release: 0.03
    ).to_output

    synth.play("A4", duration: 0.05)
    buffer = context.render

    expect(buffer.peak).to be_between(0.1, 1.0)
    expect(buffer).to have_frequency(440, tolerance: 20)
    expect(buffer.mono.first(100).max).to be > 0.0
    expect(buffer.mono.last(1_000).map(&:abs).max).to be < 0.05
  end

  it "mixes multiple notes through PolySynth" do
    context = Deftones::OfflineContext.new(duration: 0.3)
    synth = Deftones::PolySynth.new(Deftones::Synth, voices: 3, context: context).to_output

    synth.play(%w[C4 E4 G4], duration: 0.08)
    buffer = context.render

    expect(buffer.peak).to be > 0.1
    expect(buffer.rms).to be > 0.01
  end

  it "supports node chaining with gain" do
    context = Deftones::OfflineContext.new(duration: 0.1)
    oscillator = Deftones::Oscillator.new(type: :sine, frequency: 220, context: context).start(0.0)
    gain = Deftones::Gain.new(gain: 0.25, context: context)

    oscillator >> gain >> context.output
    buffer = context.render

    expect(buffer.peak).to be_between(0.05, 0.3)
  end

  it "preserves stereo channels through Envelope" do
    context = Deftones::OfflineContext.new(duration: 0.04, sample_rate: 100, buffer_size: 4, channels: 2)
    merge = Deftones::Merge.new(context: context)
    left_source = Deftones::UserMedia.new(
      buffer: Deftones::Buffer.from_mono([1.0, 1.0, 1.0, 1.0], sample_rate: 100),
      context: context
    ).start(0.0)
    right_source = Deftones::UserMedia.new(
      buffer: Deftones::Buffer.from_mono([0.5, 0.5, 0.5, 0.5], sample_rate: 100),
      context: context
    ).start(0.0)
    envelope = Deftones::Envelope.new(attack: 0.0, decay: 0.0, sustain: 1.0, release: 0.0, context: context)

    left_source >> merge.left
    right_source >> merge.right
    merge >> envelope >> context.output
    envelope.trigger_attack(0.0, 1.0)
    buffer = context.render

    expect(buffer.get_channel_data(0)).to eq([1.0, 1.0, 1.0, 1.0])
    expect(buffer.get_channel_data(1)).to eq([0.5, 0.5, 0.5, 0.5])
  end
end
