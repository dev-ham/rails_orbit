require "rails_helper"

RSpec.describe RailsOrbit::DashboardController, type: :request do
  describe "GET /orbit" do
    it "returns success" do
      get "/orbit"
      expect(response).to have_http_status(:ok)
    end

    it "renders the overview page" do
      get "/orbit"
      expect(response.body).to include("Overview")
    end
  end

  describe "GET /orbit/jobs" do
    it "returns success" do
      get "/orbit/jobs"
      expect(response).to have_http_status(:ok)
    end

    it "renders the jobs page" do
      get "/orbit/jobs"
      expect(response.body).to include("Jobs")
    end

    it "displays queue data when metrics exist" do
      RailsOrbit::Metric.record(key: "solid_queue.enqueued", value: 5, dimension: "default")
      get "/orbit/jobs"
      expect(response.body).to include("default")
    end
  end

  describe "GET /orbit/cache" do
    it "returns success" do
      get "/orbit/cache"
      expect(response).to have_http_status(:ok)
    end

    it "renders the cache page" do
      get "/orbit/cache"
      expect(response.body).to include("Cache")
    end
  end

  describe "GET /orbit/errors" do
    it "returns success" do
      get "/orbit/errors"
      expect(response).to have_http_status(:ok)
    end

    it "renders the errors page" do
      get "/orbit/errors"
      expect(response.body).to include("Errors")
    end
  end

  describe "authentication" do
    it "returns 401 when using default auth without credentials" do
      RailsOrbit.configuration.instance_variable_set(:@auth_block, RailsOrbit::Configuration.new.auth_block)
      get "/orbit"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 200 when providing valid credentials in dev" do
      RailsOrbit.configuration.instance_variable_set(:@auth_block, RailsOrbit::Configuration.new.auth_block)
      get "/orbit", headers: {
        "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("orbit", "orbit")
      }
      expect(response).to have_http_status(:ok)
    end

    it "returns 200 when env vars are set" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("ORBIT_USER").and_return("admin")
      allow(ENV).to receive(:[]).with("ORBIT_PASSWORD").and_return("secret123")
      RailsOrbit.configuration.instance_variable_set(:@auth_block, RailsOrbit::Configuration.new.auth_block)

      get "/orbit", headers: {
        "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", "secret123")
      }
      expect(response).to have_http_status(:ok)
    end

    it "rejects wrong credentials when env vars are set" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("ORBIT_USER").and_return("admin")
      allow(ENV).to receive(:[]).with("ORBIT_PASSWORD").and_return("secret123")
      RailsOrbit.configuration.instance_variable_set(:@auth_block, RailsOrbit::Configuration.new.auth_block)

      get "/orbit", headers: {
        "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("admin", "wrong")
      }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "range parameter" do
    it "defaults to 24h" do
      get "/orbit"
      expect(response.body).to include("24h")
    end

    it "accepts valid range params" do
      %w[1h 6h 24h 7d 30d].each do |range|
        get "/orbit", params: { range: range }
        expect(response).to have_http_status(:ok)
      end
    end

    it "ignores invalid range params and defaults to 24h" do
      get "/orbit", params: { range: "invalid" }
      expect(response).to have_http_status(:ok)
    end

    it "passes range to sub-pages" do
      get "/orbit/jobs", params: { range: "7d" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("7d")
    end
  end

  describe "security headers" do
    it "sets X-Frame-Options to DENY" do
      get "/orbit"
      expect(response.headers["X-Frame-Options"]).to eq("DENY")
    end

    it "sets X-Content-Type-Options to nosniff" do
      get "/orbit"
      expect(response.headers["X-Content-Type-Options"]).to eq("nosniff")
    end

    it "sets Referrer-Policy" do
      get "/orbit"
      expect(response.headers["Referrer-Policy"]).to eq("strict-origin-when-cross-origin")
    end

    it "sets Content-Security-Policy" do
      get "/orbit"
      csp = response.headers["Content-Security-Policy"]
      expect(csp).to include("default-src 'none'")
      expect(csp).to include("script-src 'self'")
      expect(csp).to include("frame-ancestors 'none'")
    end
  end
end
