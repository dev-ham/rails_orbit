require "spec_helper"
ENV["RAILS_ENV"] ||= "test"

# Load solid_errors before the dummy app boots so its engine registers and its
# models become available — this lets the errors page be exercised end to end
# (it is otherwise a development-only dependency and absent from the test run).
require "rails/all"
require "solid_errors"

require_relative "dummy/config/environment"
require "rspec/rails"

def create_solid_errors_tables!
  conn = ActiveRecord::Base.connection
  unless conn.table_exists?(:solid_errors)
    conn.create_table(:solid_errors) do |t|
      t.text :exception_class, null: false
      t.text :message, null: false
      t.text :severity, null: false
      t.text :source
      t.datetime :resolved_at
      t.string :fingerprint, limit: 64, null: false
      t.timestamps
    end
  end

  unless conn.table_exists?(:solid_errors_occurrences)
    conn.create_table(:solid_errors_occurrences) do |t|
      t.integer :error_id, null: false
      t.text :backtrace
      t.json :context
      t.timestamps
    end
  end
end

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.before(:suite) do
    RailsOrbit::DatabaseSetup.new.run!
    create_solid_errors_tables!
  end

  config.before(:each) do
    RailsOrbit.configuration.authenticate_with { |_controller| true }
    RailsOrbit::Metric.delete_all
  end
end
