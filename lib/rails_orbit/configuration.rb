module RailsOrbit
  class Configuration
    VALID_ADAPTERS = %i[sqlite host_db external].freeze

    attr_accessor :storage_adapter, :storage_url, :retention_days,
                  :kamal_enabled, :kamal_ssh_key_path,
                  :dashboard_title, :poll_interval
    attr_reader   :auth_block

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

    def validate!
      validate_storage_adapter!
      validate_external_url!
      validate_kamal_ssh_key!
    end

    private

    def validate_storage_adapter!
      return if VALID_ADAPTERS.include?(@storage_adapter)
      raise ArgumentError, "Unknown storage_adapter: #{@storage_adapter.inspect}. Valid options: #{VALID_ADAPTERS.join(', ')}"
    end

    def validate_external_url!
      return unless @storage_adapter == :external && @storage_url.blank?
      raise ArgumentError, "storage_adapter is :external but storage_url is not set."
    end

    def validate_kamal_ssh_key!
      return unless @kamal_enabled
      return if @kamal_ssh_key_path || ENV["ORBIT_SSH_KEY_PATH"]
      raise ArgumentError, "kamal_enabled is true but kamal_ssh_key_path is not set. " \
                           "Set it in the initializer or via ORBIT_SSH_KEY_PATH env var."
    end

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
