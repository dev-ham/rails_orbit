module RailsOrbit
  module Kamal
    class ConfigReader
      DEPLOY_YML = "config/deploy.yml"

      class << self
        def load
          @config ||= begin
            path = Rails.root.join(DEPLOY_YML)
            raise "Kamal config not found at #{path}" unless path.exist?
            YAML.safe_load_file(path, permitted_classes: [Symbol])
          end
        end

        def reload!
          @config = nil
          load
        end

        def servers
          config = load
          Array(config.dig("servers", "web")) +
            Array(config.dig("servers", "workers"))
        end

        def ssh_user
          load.dig("ssh", "user") || "root"
        end
      end
    end
  end
end
