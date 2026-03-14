# frozen_string_literal: true

RSpec.describe Deftones::Music::Note do
  describe ".to_frequency" do
    it "converts scientific pitch notation to hertz" do
      expect(described_class.to_frequency("A4")).to be_within(0.001).of(440.0)
      expect(described_class.to_frequency("C4")).to be_within(0.01).of(261.625)
    end

    it "accepts flat note names" do
      expect(described_class.to_frequency("Bb3")).to be_within(0.01).of(233.082)
    end
  end

  describe ".from_frequency" do
    it "maps frequency back to the closest note name" do
      expect(described_class.from_frequency(440.0)).to eq("A4")
    end
  end

  describe ".to_midi" do
    it "returns the midi note number" do
      expect(described_class.to_midi("C4")).to eq(60)
      expect(described_class.to_midi("A4")).to eq(69)
    end

    it "raises for invalid note names" do
      expect { described_class.to_midi("H2") }.to raise_error(ArgumentError)
    end
  end
end
