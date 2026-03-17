require "rails_helper"
require "rails_orbit/kamal/poller"

RSpec.describe RailsOrbit::Kamal::Poller do
  describe ".available?" do
    it "returns a boolean" do
      result = described_class.available?
      expect([true, false]).to include(result)
    end
  end

  describe ".start!" do
    context "when sshkit is not available" do
      before do
        allow(described_class).to receive(:available?).and_return(false)
      end

      it "logs a warning and returns nil" do
        expect(Rails.logger).to receive(:warn).with(/requires the sshkit gem/)
        expect(described_class.start!).to be_nil
      end
    end
  end

  describe "#run" do
    it "logs error when ssh key path is not set" do
      RailsOrbit.configuration.kamal_enabled = true
      RailsOrbit.configuration.kamal_ssh_key_path = nil

      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("ORBIT_SSH_KEY_PATH").and_return(nil)

      deploy_yml_path = Rails.root.join("config", "deploy.yml")
      FileUtils.mkdir_p(File.dirname(deploy_yml_path))
      config = { "servers" => { "web" => ["10.0.0.1"] } }
      File.write(deploy_yml_path, config.to_yaml)

      expect(Rails.logger).to receive(:error).with(/kamal_ssh_key_path must be set/)
      described_class.new.run

      FileUtils.rm_f(deploy_yml_path)
      RailsOrbit.configuration.kamal_enabled = false
    end
  end
end
