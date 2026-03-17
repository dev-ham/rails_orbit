require "rails_helper"

RSpec.describe RailsOrbit::Instrumentation do
  after do
    described_class.unsubscribe!
  end

  describe ".translate" do
    def make_event(name, payload = {}, duration: 0.0)
      event = ActiveSupport::Notifications::Event.allocate
      allow(event).to receive(:name).and_return(name)
      allow(event).to receive(:payload).and_return(payload)
      allow(event).to receive(:duration).and_return(duration)
      event
    end

    it "translates enqueue.solid_queue" do
      event = make_event("enqueue.solid_queue", { queue_name: "default" })
      key, value, dimension = described_class.translate(event)
      expect(key).to eq("solid_queue.enqueued")
      expect(value).to eq(1)
      expect(dimension).to eq("default")
    end

    it "translates perform.solid_queue with duration" do
      event = make_event("perform.solid_queue", { queue_name: "mailers" }, duration: 123.456)
      key, value, dimension = described_class.translate(event)
      expect(key).to eq("solid_queue.performed_ms")
      expect(value).to eq(123.46)
      expect(dimension).to eq("mailers")
    end

    it "translates failed_execution.solid_queue" do
      event = make_event("failed_execution.solid_queue", { queue_name: "default" })
      key, value, _ = described_class.translate(event)
      expect(key).to eq("solid_queue.failed")
      expect(value).to eq(1)
    end

    it "translates retry_execution.solid_queue" do
      event = make_event("retry_execution.solid_queue", { queue_name: "default" })
      key, _, _ = described_class.translate(event)
      expect(key).to eq("solid_queue.retried")
    end

    it "translates discard_job.solid_queue" do
      event = make_event("discard_job.solid_queue", { queue_name: "default" })
      key, _, _ = described_class.translate(event)
      expect(key).to eq("solid_queue.discarded")
    end

    it "translates cache_read.active_support hit" do
      event = make_event("cache_read.active_support", { hit: true, store: "SolidCache" })
      key, value, dimension = described_class.translate(event)
      expect(key).to eq("solid_cache.read_hit")
      expect(value).to eq(1)
      expect(dimension).to eq("SolidCache")
    end

    it "translates cache_read.active_support miss" do
      event = make_event("cache_read.active_support", { hit: false, store: "SolidCache" })
      key, _, _ = described_class.translate(event)
      expect(key).to eq("solid_cache.read_miss")
    end

    it "translates cache_write.active_support" do
      event = make_event("cache_write.active_support", { store: "SolidCache" })
      key, _, _ = described_class.translate(event)
      expect(key).to eq("solid_cache.write")
    end

    it "translates cache_delete.active_support" do
      event = make_event("cache_delete.active_support", { store: "SolidCache" })
      key, _, _ = described_class.translate(event)
      expect(key).to eq("solid_cache.delete")
    end

    it "translates cache_fetch_hit.active_support" do
      event = make_event("cache_fetch_hit.active_support", { store: "SolidCache" })
      key, _, _ = described_class.translate(event)
      expect(key).to eq("solid_cache.fetch_hit")
    end

    it "translates error_recorded.solid_errors" do
      event = make_event("error_recorded.solid_errors", { exception_class: "RuntimeError" })
      key, value, dimension = described_class.translate(event)
      expect(key).to eq("solid_errors.recorded")
      expect(value).to eq(1)
      expect(dimension).to eq("RuntimeError")
    end

    it "returns nil for unknown events" do
      event = make_event("unknown.event", {})
      expect(described_class.translate(event)).to be_nil
    end
  end

  describe ".subscribe!" do
    it "subscribes to all events" do
      expect { described_class.subscribe! }.not_to raise_error
    end
  end
end
