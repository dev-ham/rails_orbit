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
          "db/migrate/create_orbit_metrics.rb"
        )
      end

      def mount_route
        route 'mount RailsOrbit::Engine, at: "/orbit"'
      end

      def print_next_steps
        say "\n"
        say "rails_orbit installed!", :green
        say "Next steps:"
        say "  1. Run:  bin/rails db:migrate"
        say "  2. Edit: config/initializers/rails_orbit.rb"
        say "  3. Set:  ORBIT_USER and ORBIT_PASSWORD in your environment"
        say "  4. Visit /orbit in your browser"
        say "\n"
        say "If you are deploying to Heroku or another ephemeral platform:", :yellow
        say "  Set config.storage_adapter = :host_db in the initializer.", :yellow
      end
    end
  end
end
