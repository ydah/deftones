# frozen_string_literal: true

RSpec.describe Deftones::Context do
  class FakeRealtimeBackend
    attr_reader :samples, :stopped, :closed

    def initialize(context:)
      @context = context
      @samples = nil
      @stopped = false
      @closed = false
    end

    def start
      @samples = @context.send(:pull_realtime_samples, 4)
      self
    end

    def stop
      @stopped = true
      self
    end

    def close
      @closed = true
      self
    end

    def time
      0.25
    end
  end

  class FailingRealtimeBackend
    def initialize(context:)
      @context = context
    end

    def start
      raise "stream open failed"
    end

    def close
      true
    end
  end

  it "renders through an injected realtime backend" do
    context = described_class.new(sample_rate: 8, channels: 2, realtime_backend: FakeRealtimeBackend)
    buffer = Deftones::Buffer.from_mono([0.25, 0.25, 0.25, 0.25], sample_rate: 8)
    user_media = Deftones::UserMedia.new(buffer: buffer, context: context).start(0.0)
    user_media >> context.instance_variable_get(:@output)

    context.start
    backend = context.instance_variable_get(:@stream)

    expect(context.realtime?).to eq(true)
    expect(context.current_time).to eq(0.25)
    expect(backend.samples).to eq([0.25, 0.25, 0.25, 0.25, 0.25, 0.25, 0.25, 0.25])

    context.stop

    expect(backend.stopped).to eq(true)
    expect(backend.closed).to eq(true)
  end

  it "autostarts when its output is accessed" do
    context = described_class.new(realtime_backend: FakeRealtimeBackend)

    expect(context.running?).to eq(false)

    context.output

    expect(context.running?).to eq(true)
    expect(context.realtime?).to eq(true)
  end

  it "records backend errors without crashing the context" do
    context = described_class.new(realtime_backend: FailingRealtimeBackend)

    context.start

    expect(context.running?).to eq(true)
    expect(context.realtime?).to eq(false)
    expect(context.stream_error).to be_a(RuntimeError)
    expect(context.stream_error.message).to eq("stream open failed")
  end
end
