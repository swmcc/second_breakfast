require "rails_helper"

RSpec.describe "Observability" do
  describe "request ids" do
    it "includes ActionDispatch::RequestId in the middleware stack" do
      expect(Rails.application.middleware.map(&:name)).to include("ActionDispatch::RequestId")
    end

    it "echoes an X-Request-Id response header so a user-reported error can be traced" do
      get rails_health_check_path

      expect(response.headers["X-Request-Id"]).to be_present
    end

    it "reuses a caller-supplied request id" do
      get rails_health_check_path, headers: { "X-Request-Id" => "trace-me-123" }

      expect(response.headers["X-Request-Id"]).to eq("trace-me-123")
    end

    it "exposes the request id to the log and Sentry context during the request" do
      get health_check_path, headers: { "X-Request-Id" => "trace-me-456" }

      expect(JSON.parse(response.body)["request_id"]).to eq("trace-me-456")
    end
  end

  describe "GET /up" do
    it "returns the Rails liveness check" do
      get rails_health_check_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /health" do
    it "reports ok and verifies database connectivity" do
      get health_check_path

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to include("status" => "ok", "checks" => { "database" => true })
    end

    it "reports service unavailable when the database is unreachable" do
      allow_any_instance_of(HealthController).to receive(:database_ok?).and_return(false)

      get health_check_path

      expect(response).to have_http_status(:service_unavailable)
      expect(JSON.parse(response.body)).to include("status" => "error", "checks" => { "database" => false })
    end
  end
end
