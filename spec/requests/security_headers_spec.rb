# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Security headers" do
  # ApplicationController uses `allow_browser versions: :modern`, which returns
  # 406 for user agents it cannot parse as a modern browser.
  let(:modern_browser_headers) do
    {
      "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
                           "(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
    }
  end

  describe "GET /" do
    before { get root_path, headers: modern_browser_headers }

    it "responds successfully" do
      expect(response).to have_http_status(:ok)
    end

    it "sets a Content-Security-Policy header" do
      expect(response.headers["Content-Security-Policy"]).to be_present
    end

    it "restricts the policy to the expected sources" do
      csp = response.headers["Content-Security-Policy"]

      expect(csp).to include("default-src 'self'")
      expect(csp).to include("object-src 'none'")
      expect(csp).to include("frame-ancestors 'none'")
      expect(csp).to include("connect-src 'self'")
      expect(csp).to include("img-src 'self' data: https:")
      expect(csp).to include("font-src 'self' data:")
      expect(csp).to include("style-src 'self' 'unsafe-inline'")
    end

    it "nonces the script-src directive so importmap tags are permitted" do
      csp = response.headers["Content-Security-Policy"]

      expect(csp).to match(/script-src 'self' 'nonce-[^']+'/)
    end

    it "sets a Permissions-Policy header" do
      policy = response.headers["Permissions-Policy"]

      expect(policy).to be_present
      %w[camera gyroscope microphone usb geolocation].each do |feature|
        expect(policy).to include("#{feature}=()")
      end
    end

    it "sets a Referrer-Policy header" do
      expect(response.headers["Referrer-Policy"]).to eq("strict-origin-when-cross-origin")
    end
  end

  describe "GET /api-docs/index.html" do
    # The Swagger UI is a mounted Rack engine that renders inline scripts and
    # supplies its own (looser) CSP header, which Rails leaves untouched.
    before { get "/api-docs/index.html", headers: modern_browser_headers }

    it "still renders" do
      expect(response).to have_http_status(:ok)
    end

    it "keeps its own Content-Security-Policy allowing inline scripts" do
      expect(response.headers["Content-Security-Policy"]).to include("script-src 'self' 'unsafe-inline'")
    end
  end
end
