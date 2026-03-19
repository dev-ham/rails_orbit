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
      response.headers["Content-Security-Policy"] = "default-src 'none'; " \
        "style-src 'self' 'unsafe-inline'; " \
        "script-src 'self' 'unsafe-inline'; " \
        "img-src 'self' data:; " \
        "connect-src 'self'; " \
        "font-src 'self'; " \
        "frame-ancestors 'none'"
    end
  end
end
