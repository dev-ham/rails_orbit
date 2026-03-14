require "rails_orbit/version"
require "rails_orbit/configuration"
require "rails_orbit/metric_writer"
require "rails_orbit/instrumentation"
require "rails_orbit/engine"

module RailsOrbit
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield configuration
      configuration.validate!
    end

    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end
