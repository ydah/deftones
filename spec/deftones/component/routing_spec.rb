# frozen_string_literal: true

RSpec.describe "Additional routing components" do
  def constant_buffer(value, frames: 512, sample_rate: 44_100)
    Deftones::Buffer.from_mono(Array.new(frames, value), sample_rate: sample_rate)
  end

  it "keeps Param compatible with Signal semantics" do
    context = Deftones::OfflineContext.new(duration: 0.01)
    param = Deftones::Param.new(value: "A4", units: :frequency, context: context)

    expect(param.value).to eq(440.0)
    expect(param.process(2, 0)).to eq([440.0, 440.0])
  end

  it "renders UserMedia through CrossFade" do
    context = Deftones::OfflineContext.new(duration: 0.01)
    low = Deftones::UserMedia.new(buffer: constant_buffer(0.1), context: context).start(0.0)
    high = Deftones::UserMedia.new(provider: Array.new(512, 0.5).each, context: context).start(0.0)
    cross_fade = Deftones::CrossFade.new(fade: 0.75, context: context)

    low >> cross_fade.a
    high >> cross_fade.b
    cross_fade >> context.output

    rendered = context.render

    expect(rendered.peak).to be_within(0.05).of(0.4)
    expect(rendered.rms).to be > 0.3
  end

  it "duplicates and recombines a signal through Split and Merge" do
    context = Deftones::OfflineContext.new(duration: 0.01)
    source = Deftones::UserMedia.new(buffer: constant_buffer(0.25), context: context).start(0.0)
    split = Deftones::Split.new(context: context)
    merge = Deftones::Merge.new(context: context)

    source >> split
    split.left >> merge.left
    split.right >> merge.right
    merge >> context.output

    rendered = context.render

    expect(rendered.peak).to be_within(0.05).of(0.25)
    expect(rendered.rms).to be > 0.2
  end
end
