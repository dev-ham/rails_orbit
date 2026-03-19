module RailsOrbit
  class Engine < ::Rails::Engine
    isolate_namespace RailsOrbit

    rake_tasks do
      load root.join("lib", "tasks", "rails_orbit.rake")
    end

    initializer "rails_orbit.autoload_paths", before: :set_autoload_paths do |app|
      app.config.autoload_paths << root.join("app/jobs").to_s
    end

    initializer "rails_orbit.establish_connection", after: :load_active_record do
      config.after_initialize do
        orbit_config = RailsOrbit.configuration

        conn_spec = case orbit_config.storage_adapter
        when :sqlite
          db_path = Rails.root.join("db", "rails_orbit.sqlite3")
          { adapter: "sqlite3", database: db_path.to_s, timeout: 5000 }
        when :host_db
          ActiveRecord::Base.connection_db_config.configuration_hash.dup
        when :external
          { url: orbit_config.storage_url }
        end

        RailsOrbit::ApplicationRecord.establish_connection(conn_spec)
        ensure_table_exists!
      end
    end

    initializer "rails_orbit.assets" do |app|
      if app.config.respond_to?(:assets)
        app.config.assets.precompile += %w[
          rails_orbit/application.css
          rails_orbit/application.js
        ]
      end
    end

    initializer "rails_orbit.static_assets" do |app|
      app.middleware.insert_before(::ActionDispatch::Static, ::ActionDispatch::Static, root.join("public").to_s)
    end

    initializer "rails_orbit.ephemeral_warning" do
      if RailsOrbit.configuration.storage_adapter == :sqlite
        db_path = Rails.root.join("db", "rails_orbit.sqlite3")
        warn_if_ephemeral_filesystem!(db_path)
      end
    end

    initializer "rails_orbit.instrumentation", after: "rails_orbit.establish_connection" do
      ActiveSupport.on_load(:after_initialize) do
        RailsOrbit::Instrumentation.subscribe!
      end
    end

    initializer "rails_orbit.kamal_poller", after: "rails_orbit.instrumentation" do
      ActiveSupport.on_load(:after_initialize) do
        if RailsOrbit.configuration.kamal_enabled
          require "rails_orbit/kamal/config_reader"
          require "rails_orbit/kamal/stats_collector"
          require "rails_orbit/kamal/poller"
          RailsOrbit::Kamal::Poller.start!
        end
      end
    end

    initializer "rails_orbit.shutdown_hook" do
      at_exit { RailsOrbit::MetricWriter.shutdown if defined?(RailsOrbit::MetricWriter) }
    end

    private

    def ensure_table_exists!
      conn = RailsOrbit::ApplicationRecord.connection
      table = RailsOrbit::Metric.table_name

      return if conn.table_exists?(table)

      adapter = conn.adapter_name.downcase
      if adapter.include?("sqlite")
        conn.execute <<~SQL
          CREATE TABLE IF NOT EXISTS #{table} (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            key VARCHAR(255) NOT NULL,
            value FLOAT NOT NULL,
            dimension VARCHAR(255),
            recorded_at DATETIME NOT NULL
          )
        SQL
      elsif adapter.include?("postgres")
        conn.execute <<~SQL
          CREATE TABLE IF NOT EXISTS #{table} (
            id BIGSERIAL PRIMARY KEY,
            key VARCHAR(255) NOT NULL,
            value DOUBLE PRECISION NOT NULL,
            dimension VARCHAR(255),
            recorded_at TIMESTAMP(6) NOT NULL
          )
        SQL
      else
        conn.execute <<~SQL
          CREATE TABLE IF NOT EXISTS #{table} (
            id BIGINT AUTO_INCREMENT PRIMARY KEY,
            key VARCHAR(255) NOT NULL,
            value DOUBLE NOT NULL,
            dimension VARCHAR(255),
            recorded_at DATETIME(6) NOT NULL
          )
        SQL
      end

      conn.execute "CREATE INDEX IF NOT EXISTS idx_#{table}_key_rec ON #{table} (key, recorded_at)" rescue nil
      conn.execute "CREATE INDEX IF NOT EXISTS idx_#{table}_rec ON #{table} (recorded_at)" rescue nil

      Rails.logger.info("[rails_orbit] Created #{table} table (adapter: #{adapter})")
    rescue => e
      Rails.logger.warn("[rails_orbit] Could not auto-create #{table}: #{e.message}. Run `bin/rails rails_orbit:setup` manually.")
    end

    def warn_if_ephemeral_filesystem!(db_path)
      ephemeral_signals = %w[DYNO RAILWAY_ENVIRONMENT].any? { |k| ENV.key?(k) }
      if ephemeral_signals
        platform = detected_platform
        msg = <<~WARN
          [rails_orbit] WARNING: You are using storage_adapter: :sqlite on a platform
          with an ephemeral filesystem (detected: #{platform}).
          The file at #{db_path} will be DESTROYED on every dyno restart or deploy.
          Switch to storage_adapter: :host_db or :external to persist metrics.
          See https://github.com/dev-ham/rails_orbit#storage-adapters for details.
        WARN
        Rails.logger.warn(msg)
        warn(msg)
      end
    end

    def detected_platform
      return "Heroku"  if ENV["DYNO"]
      return "Railway" if ENV["RAILWAY_ENVIRONMENT"]
      return "Fly.io"  if ENV["FLY_APP_NAME"]
      "unknown"
    end
  end
end
