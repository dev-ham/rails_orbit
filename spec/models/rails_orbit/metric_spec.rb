require "rails_helper"

RSpec.describe RailsOrbit::Metric, type: :model do
  describe "validations" do
    it "requires key" do
      metric = described_class.new(value: 1.0, recorded_at: Time.current)
      expect(metric).not_to be_valid
      expect(metric.errors[:key]).to include("can't be blank")
    end

    it "requires value" do
      metric = described_class.new(key: "test", recorded_at: Time.current)
      expect(metric).not_to be_valid
      expect(metric.errors[:value]).to include("can't be blank")
    end

    it "requires recorded_at" do
      metric = described_class.new(key: "test", value: 1.0)
      expect(metric).not_to be_valid
      expect(metric.errors[:recorded_at]).to include("can't be blank")
    end

    it "requires numeric value" do
      metric = described_class.new(key: "test", value: "abc", recorded_at: Time.current)
      expect(metric).not_to be_valid
      expect(metric.errors[:value]).to include("is not a number")
    end

    it "is valid with all required attributes" do
      metric = described_class.new(key: "test.key", value: 42.5, recorded_at: Time.current)
      expect(metric).to be_valid
    end
  end

  describe ".record" do
    it "creates a metric with the given attributes" do
      expect {
        described_class.record(key: "solid_queue.enqueued", value: 1, dimension: "default")
      }.to change(described_class, :count).by(1)

      metric = described_class.last
      expect(metric.key).to eq("solid_queue.enqueued")
      expect(metric.value).to eq(1.0)
      expect(metric.dimension).to eq("default")
      expect(metric.recorded_at).to be_present
    end

    it "accepts a custom timestamp" do
      time = 2.hours.ago
      described_class.record(key: "test", value: 1, at: time)
      expect(described_class.last.recorded_at).to be_within(1.second).of(time)
    end
  end

  describe ".recent" do
    it "returns metrics from the last N days" do
      described_class.record(key: "recent", value: 1)
      described_class.record(key: "old", value: 1, at: 5.days.ago)

      results = described_class.recent(1)
      expect(results.pluck(:key)).to eq(["recent"])
    end

    it "defaults to 1 day" do
      described_class.record(key: "today", value: 1)
      described_class.record(key: "yesterday", value: 1, at: 2.days.ago)

      expect(described_class.recent.pluck(:key)).to eq(["today"])
    end
  end

  describe ".for_key" do
    it "filters by key" do
      described_class.record(key: "a", value: 1)
      described_class.record(key: "b", value: 2)

      expect(described_class.for_key("a").count).to eq(1)
      expect(described_class.for_key("a").first.value).to eq(1.0)
    end
  end

  describe ".older_than" do
    it "returns metrics older than N days" do
      described_class.record(key: "recent", value: 1)
      described_class.record(key: "old", value: 1, at: 10.days.ago)

      results = described_class.older_than(7)
      expect(results.pluck(:key)).to eq(["old"])
    end
  end
end
