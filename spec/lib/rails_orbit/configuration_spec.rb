require "rails_helper"

RSpec.describe RailsOrbit::Configuration do
  subject(:config) { described_class.new }

  after { RailsOrbit.reset_configuration! }

  describe "#storage_adapter" do
    it "defaults to :sqlite" do
      expect(config.storage_adapter).to eq(:sqlite)
    end

    it "accepts valid adapters" do
      %i[sqlite host_db external].each do |adapter|
        config.storage_adapter = adapter
        config.storage_url = "postgres://localhost/orbit" if adapter == :external
        expect { config.validate! }.not_to raise_error
      end
    end

    it "raises on invalid adapter" do
      config.storage_adapter = :redis
      expect { config.validate! }.to raise_error(ArgumentError, /Unknown storage_adapter/)
    end
  end

  describe "#storage_url" do
    it "raises when :external adapter has no URL" do
      config.storage_adapter = :external
      config.storage_url = nil
      expect { config.validate! }.to raise_error(ArgumentError, /storage_url is not set/)
    end

    it "passes when :external adapter has a URL" do
      config.storage_adapter = :external
      config.storage_url = "postgres://localhost/orbit"
      expect { config.validate! }.not_to raise_error
    end
  end

  describe "#retention_days" do
    it "defaults to 7" do
      expect(config.retention_days).to eq(7)
    end
  end

  describe "#authenticate_with" do
    it "stores a custom auth block" do
      config.authenticate_with { |_c| "custom" }
      expect(config.auth_block.call(nil)).to eq("custom")
    end

    it "has a default auth block" do
      expect(config.auth_block).to be_a(Proc)
    end

    it "default auth block calls authenticate_or_request_with_http_basic" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("ORBIT_USER").and_return(nil)
      allow(ENV).to receive(:[]).with("ORBIT_PASSWORD").and_return(nil)

      controller = double("controller")
      expect(controller).to receive(:authenticate_or_request_with_http_basic).with("Orbit")
      config.auth_block.call(controller)
    end
  end

  describe "#validate! with kamal" do
    it "raises when kamal_enabled but no ssh key path" do
      config.kamal_enabled = true
      config.kamal_ssh_key_path = nil
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("ORBIT_SSH_KEY_PATH").and_return(nil)
      expect { config.validate! }.to raise_error(ArgumentError, /kamal_ssh_key_path/)
    end

    it "passes when kamal_enabled with ssh key path" do
      config.kamal_enabled = true
      config.kamal_ssh_key_path = "/path/to/key"
      expect { config.validate! }.not_to raise_error
    end

    it "passes when kamal_enabled with env ssh key path" do
      config.kamal_enabled = true
      config.kamal_ssh_key_path = nil
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("ORBIT_SSH_KEY_PATH").and_return("/path/to/key")
      expect { config.validate! }.not_to raise_error
    end
  end

  describe "#poll_interval" do
    it "defaults to 5" do
      expect(config.poll_interval).to eq(5)
    end
  end

  describe "#dashboard_title" do
    it "defaults to Orbit" do
      expect(config.dashboard_title).to eq("Orbit")
    end
  end

  describe "#kamal_enabled" do
    it "defaults to false" do
      expect(config.kamal_enabled).to eq(false)
    end
  end
end
