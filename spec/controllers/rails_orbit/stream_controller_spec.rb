require "rails_helper"

RSpec.describe RailsOrbit::StreamController, type: :request do
  describe "GET /orbit/stream" do
    it "returns turbo stream content" do
      get "/orbit/stream", headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    end

    it "includes turbo stream targets" do
      get "/orbit/stream", headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response.body).to include("orbit-queue-stats")
      expect(response.body).to include("orbit-cache-stats")
      expect(response.body).to include("orbit-error-count")
    end
  end
end
