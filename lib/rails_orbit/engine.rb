module RailsOrbit
  class Engine < ::Rails::Engine
    isolate_namespace RailsOrbit

    rake_tasks do
      load root.join("lib", "tasks", "rails_orbit.rake")
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

        ApplicationRecord.establish_connection(conn_spec)
        DatabaseSetup.new.run!
      rescue => e
        Rails.logger.warn("[rails_orbit] Database setup failed: #{e.message}. Run `bin/rails rails_orbit:setup` manually.")
      end
    end

    initializer "rails_orbit.assets" do |app|
      if app.config.respond_to?(:assets)
        app.config.assets.precompile += %w[rails_orbit/application.css rails_orbit/application.js]
      end
    end

    initializer "rails_orbit.static_assets" do |app|
      app.middleware.insert_before(::ActionDispatch::Static, ::ActionDispatch::Static, root.join("public").to_s)
    end

    initializer "rails_orbit.ephemeral_warning" do
      next unless RailsOrbit.configuration.storage_adapter == :sqlite

      signals = %w[DYNO RAILWAY_ENVIRONMENT FLY_APP_NAME]
      next unless signals.any? { |k| ENV.key?(k) }

      platform = ENV["DYNO"] ? "Heroku" : ENV["RAILWAY_ENVIRONMENT"] ? "Railway" : "Fly.io"
      db_path = Rails.root.join("db", "rails_orbit.sqlite3")
      msg = "[rails_orbit] WARNING: Using :sqlite on #{platform} (ephemeral filesystem). " \
            "#{db_path} will be destroyed on deploy. Use :host_db or :external instead."
      Rails.logger.warn(msg)
      warn(msg)
    end

    initializer "rails_orbit.instrumentation", after: "rails_orbit.establish_connection" do
      ActiveSupport.on_load(:after_initialize) { Instrumentation.subscribe! }
    end

    initializer "rails_orbit.kamal_poller", after: "rails_orbit.instrumentation" do
      ActiveSupport.on_load(:after_initialize) do
        next unless RailsOrbit.configuration.kamal_enabled
        require "rails_orbit/kamal/config_reader"
        require "rails_orbit/kamal/stats_collector"
        require "rails_orbit/kamal/poller"
        Kamal::Poller.start!
      end
    end

    initializer "rails_orbit.puma_fork_safety" do
      config.after_initialize do
        next unless defined?(Puma) && Puma.respond_to?(:cli_config)
        Puma.cli_config.options[:before_worker_boot] ||= []
        Puma.cli_config.options[:before_worker_boot] << ->(_) { MetricWriter.reset! }
      end
    end

    initializer "rails_orbit.shutdown_hook" do
      at_exit { MetricWriter.shutdown if defined?(MetricWriter) }
    end
  end
end
