module RailsOrbit
  class ApplicationController < ActionController::Base
    before_action :authenticate_orbit!
    before_action :set_security_headers
    layout "rails_orbit/application"

    private

    def authenticate_orbit!
      RailsOrbit.configuration.auth_block&.call(self)
    end

    def set_security_headers
      response.headers["X-Frame-Options"]        = "DENY"
      response.headers["X-Content-Type-Options"] = "nosniff"
      response.headers["Referrer-Policy"]        = "strict-origin-when-cross-origin"
    end
  end
end
