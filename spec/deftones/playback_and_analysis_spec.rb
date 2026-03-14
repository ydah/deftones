# frozen_string_literal: true

require "tmpdir"

RSpec.describe "Playback, analysis, and mixer utilities" do
  def build_test_buffer
    samples = Array.new(2_205) do |index|
      Math.sin((2.0 * Math::PI * 440.0 * index) / 44_100.0) * 0.5
    end
    Deftones::Buffer.from_mono(samples, sample_rate: 44_100)
  end

  it "renders Player, GrainPlayer, and Sampler from buffers" do
    context = Deftones::OfflineContext.new(duration: 0.25)
    buffer = build_test_buffer

    player = Deftones::Player.new(buffer: buffer, context: context)
    grain = Deftones::GrainPlayer.new(buffer: buffer, context: context)
    sampler = Deftones::Sampler.new(samples: { "C4" => buffer }, context: context)

    player >> context.output
    player.start(0.0)
    grain >> context.output
    grain.start(0.05)
    sampler.to_output.play("E4", duration: 0.1, at: 0.1)

    rendered = context.render

    expect(rendered.peak).to be > 0.05
    expect(rendered.rms).to be > 0.01
  end

  it "records offline output to a file" do
    Dir.mktmpdir do |directory|
      path = File.join(directory, "recorded.wav")
      context = Deftones::OfflineContext.new(duration: 0.1)
      Deftones::Synth.new(context: context).to_output.play("A4", duration: 0.05)

      recorder = Deftones::Recorder.new(context: context)
      buffer = recorder.record(path: path)

      expect(buffer).to be_a(Deftones::Buffer)
      expect(File).to exist(path)
    end
  end

  it "updates analyser, meter, dc meter, and channel utilities" do
    context = Deftones::OfflineContext.new(duration: 0.15)
    oscillator = Deftones::Oscillator.new(type: :sine, frequency: 220, context: context)
    analyser = Deftones::Analyser.new(size: 128, context: context)
    meter = Deftones::Meter.new(context: context)
    dc_meter = Deftones::DCMeter.new(context: context)
    channel = Deftones::Channel.new(pan: 0.2, volume: -3.0, context: context)

    oscillator >> analyser >> meter >> dc_meter >> channel >> context.output
    context.render

    expect(analyser.waveform.samples.length).to eq(128)
    expect(analyser.fft).not_to be_empty
    expect(meter.peak).to be > 0.01
    expect(meter.rms).to be > 0.01
    expect(dc_meter.offset.abs).to be < 0.1
  end

  it "provides frequency and midi helpers" do
    expect(Deftones::Frequency.parse("440hz")).to eq(440.0)
    expect(Deftones::Frequency.to_period("500hz")).to eq(0.002)
    expect(Deftones::Midi.available?).to satisfy { |value| value == true || value == false }
  end
end
