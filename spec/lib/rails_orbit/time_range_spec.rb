require "rails_helper"

RSpec.describe RailsOrbit::TimeRange do
  describe "#key" do
    it "returns valid param as-is" do
      %w[1h 6h 24h 7d 30d].each do |param|
        expect(described_class.new(param).key).to eq(param)
      end
    end

    it "defaults to 24h for invalid param" do
      expect(described_class.new("invalid").key).to eq("24h")
      expect(described_class.new(nil).key).to eq("24h")
    end
  end

  describe "#since" do
    it "returns a time in the past" do
      range = described_class.new("1h")
      expect(range.since).to be_within(2.seconds).of(1.hour.ago)
    end
  end

  describe "#bucket_minutes" do
    it "returns correct bucket for each range" do
      expect(described_class.new("1h").bucket_minutes).to eq(1)
      expect(described_class.new("7d").bucket_minutes).to eq(60)
    end
  end

  describe "#delta_window" do
    it "returns correct delta window" do
      expect(described_class.new("1h").delta_window).to eq(15.minutes)
      expect(described_class.new("30d").delta_window).to eq(1.day)
    end
  end

  describe "#label" do
    it "returns the display label" do
      expect(described_class.new("7d").label).to eq("7d")
    end
  end
end
