require "rails_helper"

RSpec.describe RailsOrbit::MetricWriter do
  after do
    described_class.reset!
  end

  describe ".write" do
    it "creates a metric asynchronously" do
      described_class.write(key: "test.write", value: 42, dimension: "spec")

      described_class.executor.shutdown
      described_class.executor.wait_for_termination(5)

      metric = RailsOrbit::Metric.last
      expect(metric).to be_present
      expect(metric.key).to eq("test.write")
      expect(metric.value).to eq(42.0)
    end

    it "does not raise on DB errors" do
      allow(RailsOrbit::Metric).to receive(:record).and_raise(ActiveRecord::StatementInvalid, "boom")

      expect {
        described_class.write(key: "fail", value: 1)
        described_class.executor.shutdown
        described_class.executor.wait_for_termination(5)
      }.not_to raise_error
    end
  end

  describe ".shutdown" do
    it "shuts down the executor gracefully" do
      described_class.executor
      expect { described_class.shutdown }.not_to raise_error
    end

    it "is safe to call when executor not initialized" do
      expect { described_class.shutdown }.not_to raise_error
    end
  end
end
