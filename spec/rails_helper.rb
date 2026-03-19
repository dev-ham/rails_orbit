require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "dummy/config/environment"
require "rspec/rails"

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.before(:suite) do
    RailsOrbit::DatabaseSetup.new.run!
  end

  config.before(:each) do
    RailsOrbit.configuration.authenticate_with { |_controller| true }
    RailsOrbit::Metric.delete_all
  end
end
