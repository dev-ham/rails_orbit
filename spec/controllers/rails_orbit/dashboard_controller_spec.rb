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

    it "returns 200 when providing valid credentials" do
      RailsOrbit.configuration.instance_variable_set(:@auth_block, RailsOrbit::Configuration.new.auth_block)
      get "/orbit", headers: {
        "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials("orbit", "changeme")
      }
      expect(response).to have_http_status(:ok)
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
  end
end
