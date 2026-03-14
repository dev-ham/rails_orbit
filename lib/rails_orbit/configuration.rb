module RailsOrbit
  class Configuration
    VALID_ADAPTERS = %i[sqlite host_db external].freeze

    attr_accessor :storage_adapter, :storage_url, :retention_days,
                  :kamal_enabled, :kamal_ssh_key_path,
                  :dashboard_title, :poll_interval

    def initialize
      @storage_adapter    = :sqlite
      @storage_url        = nil
      @retention_days     = 7
      @kamal_enabled      = false
      @kamal_ssh_key_path = nil
      @dashboard_title    = "Orbit"
      @poll_interval      = 5
      @auth_block         = default_auth_block
    end

    def authenticate_with(&block)
      @auth_block = block
    end

    def auth_block
      @auth_block
    end

    def validate!
      unless VALID_ADAPTERS.include?(@storage_adapter)
        raise ArgumentError, "[rails_orbit] Unknown storage_adapter: #{@storage_adapter.inspect}. " \
                             "Valid options: #{VALID_ADAPTERS.join(', ')}"
      end
      if @storage_adapter == :external && @storage_url.blank?
        raise ArgumentError, "[rails_orbit] storage_adapter is :external but storage_url is not set."
      end
    end

    private

    def default_auth_block
      ->(controller) {
        controller.http_basic_authenticate_with(
          name:     ENV.fetch("ORBIT_USER",     "orbit"),
          password: ENV.fetch("ORBIT_PASSWORD", "changeme")
        )
      }
    end
  end
end
