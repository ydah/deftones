# frozen_string_literal: true

require "tmpdir"

RSpec.describe Deftones do
  it "has a version number" do
    expect(described_class::VERSION).not_to be_nil
  end

  it "reports wavify availability through the compatibility helper" do
    expect(described_class.wavify_available?).to eq(true)
    expect(described_class.wavefile_available?).to eq(described_class.wavify_available?)
  end

  it "exposes the top-level MVP aliases" do
    expect(described_class::BaseContext).to eq(Deftones::Context)
    expect(described_class::ToneAudioNode).to eq(Deftones::Core::AudioNode)
    expect(described_class::Emitter).to eq(Deftones::Core::Emitter)
    expect(described_class::Clock).to eq(Deftones::Core::Clock)
    expect(described_class::Delay).to eq(Deftones::Core::Delay)
    expect(described_class::Synth).to eq(Deftones::Instrument::Synth)
    expect(described_class::PolySynth).to eq(Deftones::Instrument::PolySynth)
    expect(described_class::Oscillator).to eq(Deftones::Source::Oscillator)
    expect(described_class::BufferSource).to eq(Deftones::Source::ToneBufferSource)
    expect(described_class::ToneBufferSource).to eq(Deftones::Source::ToneBufferSource)
    expect(described_class::ToneOscillatorNode).to eq(Deftones::Source::ToneOscillatorNode)
    expect(described_class::UserMedia).to eq(Deftones::Source::UserMedia)
    expect(described_class::BiquadFilter).to eq(Deftones::Component::BiquadFilter)
    expect(described_class::Destination).to eq(Deftones::Destination)
    expect(described_class::Draw).to eq(Deftones::Draw)
    expect(described_class::Listener).to eq(Deftones::Listener)
    expect(described_class::FeedbackCombFilter).to eq(Deftones::Component::FeedbackCombFilter)
    expect(described_class::Filter).to eq(Deftones::Component::Filter)
    expect(described_class::Follower).to eq(Deftones::Component::Follower)
    expect(described_class::Convolver).to eq(Deftones::Component::Convolver)
    expect(described_class::CrossFade).to eq(Deftones::Component::CrossFade)
    expect(described_class::LowpassCombFilter).to eq(Deftones::Component::LowpassCombFilter)
    expect(described_class::Merge).to eq(Deftones::Component::Merge)
    expect(described_class::MidSideCompressor).to eq(Deftones::Component::MidSideCompressor)
    expect(described_class::MidSideMerge).to eq(Deftones::Component::MidSideMerge)
    expect(described_class::MidSideSplit).to eq(Deftones::Component::MidSideSplit)
    expect(described_class::Mono).to eq(Deftones::Component::Mono)
    expect(described_class::MultibandCompressor).to eq(Deftones::Component::MultibandCompressor)
    expect(described_class::MultibandSplit).to eq(Deftones::Component::MultibandSplit)
    expect(described_class::OnePoleFilter).to eq(Deftones::Component::OnePoleFilter)
    expect(described_class::Panner3D).to eq(Deftones::Component::Panner3D)
    expect(described_class::Split).to eq(Deftones::Component::Split)
    expect(described_class::Param).to eq(Deftones::Core::Param)
    expect(described_class::SyncedSignal).to eq(Deftones::Core::SyncedSignal)
    expect(described_class::Buffers).to eq(Deftones::IO::Buffers)
    expect(described_class::ToneAudioBuffer).to eq(Deftones::IO::Buffer)
    expect(described_class::ToneAudioBuffers).to eq(Deftones::IO::Buffers)
    expect(described_class::Note).to eq(Deftones::Music::Note)
    expect(described_class::FrequencyClass).to eq(Deftones::Music::Frequency)
    expect(described_class::MidiClass).to eq(Deftones::Music::Midi)
    expect(described_class::Ticks).to eq(Deftones::Music::Ticks)
    expect(described_class::TicksClass).to eq(Deftones::Music::Ticks)
    expect(described_class::Time).to eq(Deftones::Music::Time)
    expect(described_class::TimeClass).to eq(Deftones::Music::Time)
    expect(described_class::TransportTime).to eq(Deftones::Music::TransportTime)
    expect(described_class::TransportTimeClass).to eq(Deftones::Music::TransportTime)
    expect(described_class::Master).to eq(Deftones::Destination)
  end

  it "renders audio through the convenience API" do
    buffer = described_class.render(duration: 0.1) do |context|
      synth = described_class::Synth.new(context: context).to_output
      synth.play("A4", duration: 0.02)
    end

    expect(buffer).to be_a(Deftones::IO::Buffer)
    expect(buffer.frames).to eq(4_410)
    expect(buffer.peak).to be > 0.1
    expect(buffer.rms).to be > 0.01
  end

  it "exposes compatibility top-level helpers" do
    described_class.reset!
    described_class.start(use_realtime: false)

    expect(described_class.supported).to eq(true)
    expect(described_class.loaded).to eq(true)
    expect(described_class.version).to eq(described_class::VERSION)
    expect(described_class.getContext).to eq(described_class.context)
    expect(described_class.getTransport).to eq(described_class.transport)
    expect(described_class.destination).to be_a(described_class::Destination)
    expect(described_class.destination.node).to eq(described_class.output)
    expect(described_class.master).to eq(described_class.destination)
    expect(described_class.getDestination).to eq(described_class.destination)
    expect(described_class.getDraw).to eq(described_class.draw)
    expect(described_class.getListener).to eq(described_class.listener)
    expect(described_class.immediate).to be_within(0.05).of(described_class.now)
    expect(described_class.dbToGain(-6)).to be_within(0.001).of(0.501)
    expect(described_class.gainToDb(0.5)).to be_within(0.001).of(-6.021)
    expect(described_class.mtof(69)).to eq(440.0)
    expect(described_class.ftom("440hz")).to eq(69)
    expect(described_class.intervalToFrequencyRatio(12)).to eq(2.0)
    expect(described_class.isArray([1, 2])).to eq(true)
    expect(described_class.isBoolean(false)).to eq(true)
    expect(described_class.isDefined("value")).to eq(true)
    expect(described_class.isFunction(-> {})).to eq(true)
    expect(described_class.isNote("A4")).to eq(true)
    expect(described_class.isNumber(12)).to eq(true)
    expect(described_class.isObject({ value: 1 })).to eq(true)
    expect(described_class.isString("tone")).to eq(true)
    expect(described_class.isUndef(nil)).to eq(true)
    expect(described_class.frequency("A4").to_hz).to eq(440.0)
    expect(described_class.midi("A4").to_i).to eq(69)
    expect(described_class.time("4n").to_seconds).to eq(0.5)
    expect(described_class.ticks("4n").to_i).to eq(192)
    expect(described_class.transportTime("1:0:0").to_seconds).to eq(2.0)
  ensure
    described_class.reset!
  end

  it "switches the global context through compatibility helpers" do
    described_class.reset!
    context = described_class::OfflineContext.new(duration: 0.05)

    expect(described_class.setContext(context)).to eq(described_class)
    expect(described_class.getContext).to eq(context)
    expect(context.rawContext).to eq(context)
    expect(context.sampleTime).to eq(1.0 / context.sample_rate)
    expect(context.blockTime).to eq(context.buffer_size.to_f / context.sample_rate)
    expect(context.latencyHint).to eq("interactive")
    expect(context.lookAhead).to eq(context.buffer_size.to_f / context.sample_rate)
  ensure
    described_class.reset!
  end

  it "renders through offline helper aliases" do
    rendered = described_class.offline(duration: 0.05, sample_rate: 100) do |context|
      source = described_class::UserMedia.new(
        buffer: described_class::Buffer.new([0.5] * 5, channels: 1, sample_rate: 100),
        context: context
      ).start(0.0)
      source >> context.output
    end

    expect(rendered.samples.first).to eq(0.5)
    expect(described_class.Offline(duration: 0.05, sample_rate: 100) { |context| described_class::UserMedia.new(buffer: described_class::Buffer.new([0.25] * 5, channels: 1, sample_rate: 100), context: context).start(0.0) >> context.output }.samples.first).to eq(0.25)
  end

  it "exposes compatibility listener helpers" do
    described_class.reset!
    listener = described_class.listener

    listener.setPosition(1.0, 2.0, 3.0)
    listener.setOrientation(0.0, 0.0, -1.0, 0.0, 1.0, 0.0)

    expect(listener.positionX.value).to eq(1.0)
    expect(listener.positionY.value).to eq(2.0)
    expect(listener.positionZ.value).to eq(3.0)
    expect(listener.forwardZ.value).to eq(-1.0)
    expect(listener.upY.value).to eq(1.0)
  ensure
    described_class.reset!
  end

  it "connects nodes through the compatibility helpers" do
    context = described_class::OfflineContext.new(duration: 0.05, sample_rate: 100)
    first = described_class::UserMedia.new(buffer: described_class::Buffer.new([0.1] * 5, channels: 1, sample_rate: 100), context: context).start(0.0)
    second = described_class::UserMedia.new(buffer: described_class::Buffer.new([0.15] * 5, channels: 1, sample_rate: 100), context: context).start(0.0)
    stage = described_class::Gain.new(context: context, gain: 1.0)

    expect(described_class.connectSeries(first, stage, context.output)).to eq(context.output)
    expect(described_class.connect(first, stage)).to eq(stage)
    expect(described_class.connectSignal(second, stage)).to eq(stage)
    expect(described_class.fanIn(stage, first, second)).to eq(stage)
    expect(described_class.disconnect(first, stage)).to eq(first)
    expect(context.render.peak).to eq(0.15)
  end

  it "controls destination volume and mute through the compatibility wrapper" do
    context = described_class::OfflineContext.new(duration: 0.05, sample_rate: 100)
    destination = described_class::Destination.node(context: context)

    destination.volume.value = -6.0
    expect(context.output.gain.value).to be_within(0.001).of(described_class.db_to_gain(-6.0))
    expect(destination.name).to eq("Destination")
    expect(destination.maxChannelCount).to eq(context.channels)
    expect(destination.sampleTime).to eq(0.01)
    expect(destination.blockTime).to eq(context.buffer_size.to_f / context.sample_rate)

    destination.mute = true
    expect(context.output.gain.value).to eq(0.0)
    expect(destination.mute?).to eq(true)

    destination.mute = false
    expect(context.output.gain.value).to be_within(0.001).of(described_class.db_to_gain(-6.0))
  end

  it "materializes Draw callbacks during offline rendering" do
    described_class.reset!
    callback_times = []

    described_class.draw.schedule("4n") { |time| callback_times << [:quarter, time] }
    described_class.draw.schedule(-> { callback_times << [:immediate, nil] }, 0.0)

    described_class.transport.bpm = 120
    described_class::OfflineContext.new(duration: 0.6).render

    expect(callback_times).to eq([[:immediate, nil], [:quarter, 0.5]])

    event_id = described_class.draw.schedule(0.25) { callback_times << [:cancelled, nil] }
    described_class.draw.cancel(event_id)
    described_class.draw.dispose
    described_class::OfflineContext.new(duration: 0.3).render

    expect(callback_times).to eq([[:immediate, nil], [:quarter, 0.5]])
  ensure
    described_class.reset!
  end

  it "writes a wav file through render_to_file" do
    Dir.mktmpdir do |directory|
      path = File.join(directory, "example.wav")

      described_class.render_to_file(path, duration: 0.1) do |context|
        synth = described_class::Synth.new(context: context, type: :sawtooth).to_output
        synth.play("C4", duration: 0.03)
      end

      expect(File).to exist(path)
      expect(File.binread(path, 12)).to eq("RIFF" + File.binread(path, 8)[4, 4] + "WAVE")
    end
  end

  it "writes an mp3 file through render_to_file when an encoder is available" do
    skip "ffmpeg is not installed" unless ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? { |directory| File.executable?(File.join(directory, "ffmpeg")) }

    Dir.mktmpdir do |directory|
      path = File.join(directory, "example.mp3")

      described_class.render_to_file(path, duration: 0.1) do |context|
        synth = described_class::Synth.new(context: context, type: :triangle).to_output
        synth.play("A4", duration: 0.03)
      end

      expect(File).to exist(path)
      expect(described_class::Buffer.load(path).peak).to be > 0.01
    end
  end
end
