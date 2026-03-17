require_relative "boot"
require "rails/all"
require "turbo-rails"

Bundler.require(*Rails.groups)
require "rails_orbit"

module Dummy
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f
    config.eager_load = false
    config.active_job.queue_adapter = :test
  end
end
