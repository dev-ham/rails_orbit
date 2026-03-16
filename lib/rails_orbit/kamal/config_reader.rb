module RailsOrbit
  module Kamal
    class ConfigReader
      DEPLOY_YML = "config/deploy.yml"

      def self.load
        path = Rails.root.join(DEPLOY_YML)
        raise "[rails_orbit] Kamal config not found at #{path}" unless path.exist?
        YAML.safe_load_file(path, permitted_classes: [Symbol])
      end

      def self.servers
        config = load
        Array(config.dig("servers", "web")) +
          Array(config.dig("servers", "workers"))
      end

      def self.ssh_user
        load.dig("ssh", "user") || "root"
      end
    end
  end
end
