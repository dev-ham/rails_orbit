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
      if @kamal_enabled && @kamal_ssh_key_path.nil? && ENV["ORBIT_SSH_KEY_PATH"].nil?
        raise ArgumentError, "[rails_orbit] kamal_enabled is true but kamal_ssh_key_path is not set. " \
                             "Set it in the initializer or via ORBIT_SSH_KEY_PATH env var."
      end
    end

    private

    def default_auth_block
      ->(controller) {
        user     = ENV["ORBIT_USER"]
        password = ENV["ORBIT_PASSWORD"]

        if user.nil? || password.nil?
          if Rails.env.production?
            Rails.logger.error("[rails_orbit] ORBIT_USER and ORBIT_PASSWORD must be set in production. Dashboard access denied.")
            controller.head(:forbidden)
            return
          else
            user     ||= "orbit"
            password ||= "orbit"
          end
        end

        controller.authenticate_or_request_with_http_basic("Orbit") do |name, pwd|
          ActiveSupport::SecurityUtils.secure_compare(name, user) &
            ActiveSupport::SecurityUtils.secure_compare(pwd, password)
        end
      }
    end
  end
end
