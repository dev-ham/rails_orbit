require "rails_helper"

RSpec.describe RailsOrbit::Metric do
  describe ".record" do
    it "creates a metric with all attributes" do
      metric = described_class.record(key: "test.key", value: 42, dimension: "web")
      expect(metric).to be_persisted
      expect(metric.key).to eq("test.key")
      expect(metric.value).to eq(42.0)
      expect(metric.dimension).to eq("web")
    end
  end

  describe ".hit_rate" do
    it "computes percentage from hits and misses" do
      expect(described_class.hit_rate(80, 20)).to eq(80.0)
    end

    it "returns 0 when total is zero" do
      expect(described_class.hit_rate(0, 0)).to eq(0.0)
    end
  end

  describe ".sums_since" do
    it "returns hash of key => sum" do
      described_class.record(key: "a", value: 3)
      described_class.record(key: "a", value: 7)
      described_class.record(key: "b", value: 1)

      sums = described_class.sums_since(1.hour.ago)
      expect(sums["a"]).to eq(10.0)
      expect(sums["b"]).to eq(1.0)
    end
  end

  describe ".compute_delta" do
    it "returns flat when no data" do
      result = described_class.compute_delta("missing.key", window: 1.hour)
      expect(result[:direction]).to eq(:flat)
      expect(result[:value]).to eq(0)
    end

    it "returns up 100% when previous is zero" do
      described_class.record(key: "test.delta", value: 5, at: 10.minutes.ago)
      result = described_class.compute_delta("test.delta", window: 1.hour)
      expect(result[:direction]).to eq(:up)
      expect(result[:value]).to eq(100)
    end
  end

  describe ".bucketed_series" do
    it "returns time-bucketed data" do
      described_class.record(key: "test.bucket", value: 10, at: 30.minutes.ago)
      described_class.record(key: "test.bucket", value: 20, at: 15.minutes.ago)

      result = described_class.bucketed_series("test.bucket", since: 1.hour.ago, bucket_minutes: 15)
      expect(result).to be_an(Array)
      expect(result.first).to have_key(:t)
      expect(result.first).to have_key(:v)
    end
  end

  describe ".bucketed_hit_rate_series" do
    it "returns hit rate buckets" do
      described_class.record(key: "solid_cache.read_hit", value: 8, at: 30.minutes.ago)
      described_class.record(key: "solid_cache.read_miss", value: 2, at: 30.minutes.ago)

      result = described_class.bucketed_hit_rate_series(since: 1.hour.ago, bucket_minutes: 60)
      expect(result).to be_an(Array)
      expect(result.first[:v]).to eq(80.0)
    end
  end

  describe "scopes" do
    it ".since filters by time" do
      described_class.record(key: "new", value: 1, at: 1.minute.ago)
      described_class.record(key: "old", value: 1, at: 2.hours.ago)
      expect(described_class.since(1.hour.ago).count).to eq(1)
    end

    it ".older_than filters old records" do
      described_class.record(key: "new", value: 1)
      described_class.record(key: "old", value: 1, at: 10.days.ago)
      expect(described_class.older_than(7).count).to eq(1)
    end
  end
end
