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

  it "exposes compatibility recorder helpers" do
    Dir.mktmpdir do |directory|
      path = File.join(directory, "captured.wav")
      context = Deftones::OfflineContext.new(duration: 0.1)
      Deftones::Synth.new(context: context).to_output.play("A4", duration: 0.05)

      recorder = Deftones::Recorder.new(context: context, mime_type: "audio/wav")
      expect(recorder.state).to eq(:stopped)
      expect(recorder.mimeType).to eq("audio/wav")

      recorder.start
      expect(recorder.state).to eq(:started)

      buffer = recorder.stop(path: path)

      expect(recorder.state).to eq(:stopped)
      expect(buffer).to be_a(Deftones::Buffer)
      expect(File).to exist(path)

      recorder.dispose
      expect(recorder.captured_buffer).to eq(nil)
    end
  end

  it "updates analyser, meter, dc meter, and channel utilities" do
    context = Deftones::OfflineContext.new(duration: 0.15)
    oscillator = Deftones::Oscillator.new(type: :sine, frequency: 220, context: context).start(0.0)
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

  it "exposes compatibility meter helpers" do
    context = Deftones::OfflineContext.new(duration: 0.15)
    oscillator = Deftones::Oscillator.new(type: :sine, frequency: 220, context: context).start(0.0)
    meter = Deftones::Meter.new(smoothing: 0.0, normal_range: true, context: context)
    dc_meter = Deftones::DCMeter.new(smoothing: 0.0, context: context)

    oscillator >> meter >> dc_meter >> context.output
    context.render

    expect(meter.channels).to eq(1)
    expect(meter.getValue).to be_between(0.0, 1.0)
    meter.normalRange = false
    expect(meter.get_value).to be < 0.0
    expect(dc_meter.getValue.abs).to be < 0.1
  end

  it "exposes compatibility channel helpers" do
    context = Deftones::OfflineContext.new(duration: 0.05, sample_rate: 100, buffer_size: 5)
    source = Deftones::UserMedia.new(
      buffer: Deftones::Buffer.from_mono([1.0, 1.0, 1.0, 1.0, 1.0], sample_rate: 100),
      context: context
    ).start(0.0)
    sender = Deftones::Channel.new(pan: 0.2, volume: -6.0, context: context)
    receiver = Deftones::Channel.new(mute: false, context: context)

    source >> sender >> context.output
    sender.send(:fx, -3.0)
    receiver.receive(:fx)
    receiver >> context.output
    context.render

    expect(sender.pan.value).to eq(0.2)
    expect(sender.volume.value).to be_within(0.001).of(Deftones.db_to_gain(-6.0))
    expect(sender.panVol).to eq(sender.pan_vol)
    expect(receiver.mute?).to eq(false)
    expect(receiver.muted).to eq(false)

    receiver.muted = true
    expect(receiver.mute?).to eq(true)
    expect(receiver.muted?).to eq(true)

    sender.solo = true
    expect(sender.solo).to eq(true)
    expect(sender.solo?).to eq(true)

    sender.dispose
    receiver.dispose
  end

  it "folds pan values with equal-power gain in mono rendering" do
    context = Deftones::OfflineContext.new(duration: 0.03, sample_rate: 100, buffer_size: 3)
    source = Deftones::UserMedia.new(
      buffer: Deftones::Buffer.from_mono([1.0, 1.0, 1.0], sample_rate: 100),
      context: context
    ).start(0.0)
    left = Deftones::Panner.new(pan: -1.0, context: context)
    center = Deftones::Panner.new(pan: 0.0, context: context)
    right = Deftones::Panner.new(pan: 1.0, context: context)

    source >> left
    left_output = left.render(3, 0)
    source.disconnect(left)
    source >> center
    center_output = center.render(3, 0)
    source.disconnect(center)
    source >> right
    right_output = right.render(3, 0)

    expect(left_output).to all(be_within(0.001).of(0.5))
    expect(center_output).to all(be_within(0.001).of(Math.sqrt(0.5)))
    expect(right_output).to all(be_within(0.001).of(0.5))
  end

  it "exposes compatibility analyser value helpers" do
    context = Deftones::OfflineContext.new(duration: 0.15)
    oscillator = Deftones::Oscillator.new(type: :sine, frequency: 220, context: context).start(0.0)
    analyser = Deftones::Analyser.new(size: 64, type: :waveform, smoothing: 0.0, normal_range: true, context: context)

    oscillator >> analyser >> context.output
    context.render

    waveform_values = analyser.getValue
    expect(waveform_values.length).to eq(64)
    expect(waveform_values).to all(satisfy { |value| value.between?(0.0, 1.0) })

    analyser.type = :fft
    analyser.returnType = :byte
    fft_values = analyser.getValue
    expect(fft_values.length).to eq(32)
    expect(fft_values).to all(satisfy { |value| value.between?(0, 255) })

    analyser.size = 32
    analyser.return_type = :float
    analyser.normalRange = false
    analyser.minDecibels = -80.0
    analyser.maxDecibels = -10.0
    decibel_values = analyser.get_value

    expect(decibel_values.length).to eq(16)
    expect(decibel_values.max).to be <= -10.0
    expect(decibel_values.min).to be >= -80.0
  end

  it "preserves stereo channels through analysis nodes" do
    context = Deftones::OfflineContext.new(duration: 0.05, sample_rate: 100, buffer_size: 5, channels: 2)
    merge = Deftones::Merge.new(context: context)
    left_source = Deftones::UserMedia.new(
      buffer: Deftones::Buffer.from_mono(Array.new(5, 0.2), sample_rate: 100),
      context: context
    ).start(0.0)
    right_source = Deftones::UserMedia.new(
      buffer: Deftones::Buffer.from_mono(Array.new(5, 0.6), sample_rate: 100),
      context: context
    ).start(0.0)
    analyser = Deftones::Analyser.new(size: 8, type: :waveform, context: context)
    meter = Deftones::Meter.new(channels: 2, smoothing: 0.0, normal_range: true, context: context)
    dc_meter = Deftones::DCMeter.new(channels: 2, smoothing: 0.0, context: context)

    left_source >> merge.left
    right_source >> merge.right
    merge >> analyser >> meter >> dc_meter >> context.output
    rendered = context.render

    expect(rendered.get_channel_data(0)).to all(be_within(0.001).of(0.2))
    expect(rendered.get_channel_data(1)).to all(be_within(0.001).of(0.6))
    expect(meter.getValue).to eq([0.2, 0.6])
    expect(dc_meter.getValue).to eq([0.2, 0.6])
    expect(analyser.getValue.length).to eq(8)
  end

  it "exposes FFT and Waveform analyser nodes" do
    context = Deftones::OfflineContext.new(duration: 0.15)
    oscillator = Deftones::Oscillator.new(type: :sine, frequency: 220, context: context)
    waveform = Deftones::Waveform.new(size: 64, smoothing: 0.0, normal_range: true, context: context)
    fft = Deftones::FFT.new(size: 64, return_type: :byte, normal_range: true, context: context)

    oscillator.fan(waveform, fft, context.output).start(0.0)
    context.render

    expect(waveform.getValue.length).to eq(64)
    expect(waveform.getValue).to all(satisfy { |value| value.between?(0.0, 1.0) })
    expect(fft.getValue.length).to eq(32)
    expect(fft.getValue).to all(satisfy { |value| value.between?(0, 255) })
  end

  it "provides frequency and midi helpers" do
    expect(Deftones::Frequency.parse("440hz")).to eq(440.0)
    expect(Deftones::Frequency.to_period("500hz")).to eq(0.002)
    expect(Deftones::Midi.available?).to satisfy { |value| value == true || value == false }
  end
end
