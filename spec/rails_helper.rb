require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "dummy/config/environment"
require "rspec/rails"

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.before(:suite) do
    conn = RailsOrbit::ApplicationRecord.connection
    table_name = RailsOrbit::Metric.table_name

    unless conn.table_exists?(table_name)
      conn.execute <<~SQL
        CREATE TABLE #{table_name} (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          key VARCHAR(255) NOT NULL,
          value FLOAT NOT NULL,
          dimension VARCHAR(255),
          recorded_at DATETIME NOT NULL
        )
      SQL
      conn.execute "CREATE INDEX IF NOT EXISTS idx_#{table_name}_key_recorded ON #{table_name} (key, recorded_at)"
      conn.execute "CREATE INDEX IF NOT EXISTS idx_#{table_name}_recorded ON #{table_name} (recorded_at)"
    end
  end

  config.before(:each) do
    RailsOrbit.configuration.authenticate_with { |_controller| true }
    RailsOrbit::Metric.delete_all
  end
end
