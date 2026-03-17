require "rails_helper"
require "rails_orbit/kamal/config_reader"

RSpec.describe RailsOrbit::Kamal::ConfigReader do
  let(:deploy_yml_path) { Rails.root.join("config", "deploy.yml") }

  let(:sample_config) do
    {
      "servers" => {
        "web"     => ["10.0.0.1", "10.0.0.2"],
        "workers" => ["10.0.0.3"]
      },
      "ssh" => { "user" => "deploy" }
    }
  end

  before do
    FileUtils.mkdir_p(File.dirname(deploy_yml_path))
    File.write(deploy_yml_path, sample_config.to_yaml)
  end

  after do
    FileUtils.rm_f(deploy_yml_path)
  end

  describe ".servers" do
    it "returns all web and worker servers" do
      servers = described_class.servers
      expect(servers).to eq(["10.0.0.1", "10.0.0.2", "10.0.0.3"])
    end
  end

  describe ".ssh_user" do
    it "returns the configured SSH user" do
      expect(described_class.ssh_user).to eq("deploy")
    end

    it "defaults to root when not configured" do
      config_without_ssh = { "servers" => { "web" => ["10.0.0.1"] } }
      File.write(deploy_yml_path, config_without_ssh.to_yaml)
      expect(described_class.ssh_user).to eq("root")
    end
  end

  describe ".load" do
    it "raises when deploy.yml does not exist" do
      FileUtils.rm_f(deploy_yml_path)
      expect { described_class.load }.to raise_error(RuntimeError, /Kamal config not found/)
    end
  end
end
