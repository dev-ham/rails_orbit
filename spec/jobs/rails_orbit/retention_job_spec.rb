require "rails_helper"

RSpec.describe RailsOrbit::RetentionJob, type: :job do
  describe "#perform" do
    it "purges metrics older than retention_days" do
      RailsOrbit::Metric.record(key: "recent", value: 1)
      RailsOrbit::Metric.record(key: "old", value: 1, at: 30.days.ago)

      expect {
        described_class.new.perform
      }.to change(RailsOrbit::Metric, :count).by(-1)

      expect(RailsOrbit::Metric.pluck(:key)).to eq(["recent"])
    end

    it "respects configured retention_days" do
      RailsOrbit.configuration.retention_days = 3

      RailsOrbit::Metric.record(key: "keep", value: 1, at: 2.days.ago)
      RailsOrbit::Metric.record(key: "purge", value: 1, at: 5.days.ago)

      described_class.new.perform

      expect(RailsOrbit::Metric.pluck(:key)).to eq(["keep"])
    ensure
      RailsOrbit.configuration.retention_days = 7
    end

    it "logs the purge count" do
      RailsOrbit::Metric.record(key: "old", value: 1, at: 30.days.ago)

      expect(Rails.logger).to receive(:info).with(/purged 1 metrics/)
      described_class.new.perform
    end

    it "handles zero deletions gracefully" do
      expect(Rails.logger).to receive(:info).with(/purged 0 metrics/)
      described_class.new.perform
    end
  end
end
