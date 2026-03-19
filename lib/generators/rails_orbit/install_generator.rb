require "rails/generators"
require "rails/generators/active_record"

module RailsOrbit
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      desc "Installs rails_orbit: copies migrations, creates initializer, suggests route mount."

      def create_initializer
        template "initializer.rb", "config/initializers/rails_orbit.rb"
      end

      def copy_migrations
        migration_template(
          "create_orbit_metrics.rb.erb",
          "db/migrate/create_rails_orbit_metrics.rb"
        )
      end

      def mount_route
        route 'mount RailsOrbit::Engine, at: "/orbit"'
      end

      def print_next_steps
        say "\n"
        say "rails_orbit installed!", :green
        say ""
        say "Next steps:"
        say ""
        say "  For :host_db or :external adapters:"
        say "    bin/rails db:migrate"
        say ""
        say "  For :sqlite adapter (default):"
        say "    The table is created automatically on first boot."
        say "    Or run manually: bin/rails rails_orbit:setup"
        say ""
        say "  Then:"
        say "    1. Edit config/initializers/rails_orbit.rb"
        say "    2. Set ORBIT_USER and ORBIT_PASSWORD in your environment"
        say "    3. Visit /orbit in your browser"
        say ""
        say "  Useful commands:"
        say "    bin/rails rails_orbit:setup   — create the metrics table"
        say "    bin/rails rails_orbit:status  — check config and table status"
        say ""
        say "If you are deploying to Heroku or another ephemeral platform:", :yellow
        say "  Set config.storage_adapter = :host_db in the initializer.", :yellow
      end
    end
  end
end
