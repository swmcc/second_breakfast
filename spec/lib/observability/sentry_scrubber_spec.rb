require "rails_helper"

RSpec.describe Observability::SentryScrubber do
  # Stand-ins for the parts of a Sentry event we touch, so the spec needs
  # neither an initialised SDK nor a network.
  let(:request_class) { Struct.new(:data, :headers, :env, :cookies, :query_string) }
  let(:breadcrumb_class) { Struct.new(:data) }
  let(:event_class) { Struct.new(:request, :extra, :tags, :contexts, :user, :breadcrumbs) }

  def build_request(data: {}, headers: {}, env: {}, cookies: nil, query_string: nil)
    request_class.new(data, headers, env, cookies, query_string)
  end

  def build_event(request: build_request, extra: {}, tags: {}, contexts: {}, user: {}, breadcrumbs: [])
    event_class.new(request, extra, tags, contexts, user, breadcrumbs)
  end

  it "filters credentials out of request data, headers and env" do
    request = build_request(
      data: { "email" => "a@example.com", "password" => "hunter2", "password_confirmation" => "hunter2" },
      headers: { "Authorization" => "Bearer abc123", "Accept" => "application/json" },
      env: { "HTTP_AUTHORIZATION" => "Bearer abc123" }
    )

    described_class.call(build_event(request: request))

    expect(request.data["password"]).to eq("[FILTERED]")
    expect(request.data["password_confirmation"]).to eq("[FILTERED]")
    expect(request.headers["Authorization"]).to eq("[FILTERED]")
    expect(request.headers["Accept"]).to eq("application/json")
    expect(request.env["HTTP_AUTHORIZATION"]).to eq("[FILTERED]")
  end

  it "drops cookies entirely" do
    request = build_request(cookies: { "_session_id" => "abc" })

    described_class.call(build_event(request: request))

    expect(request.cookies).to be_nil
  end

  it "drops a query string that carries a credential" do
    request = build_request(query_string: "api_key=secret&page=2")

    described_class.call(build_event(request: request))

    expect(request.query_string).to be_nil
  end

  it "keeps a harmless query string" do
    request = build_request(query_string: "page=2")

    described_class.call(build_event(request: request))

    expect(request.query_string).to eq("page=2")
  end

  it "reduces the user context to an id, dropping the email" do
    event = build_event(user: { "id" => 7, "email" => "a@example.com", "ip_address" => "1.2.3.4" })

    described_class.call(event)

    expect(event.user).to eq({ "id" => 7 })
  end

  it "filters extra, tags, contexts and breadcrumb data" do
    breadcrumb = breadcrumb_class.new({ "token" => "abc", "request_id" => "req-1" })
    event = build_event(
      extra: { "api_key" => "abc", "recipe_id" => 3 },
      tags: { "token" => "abc", "request_id" => "req-1" },
      contexts: { "custom" => { "password" => "hunter2" } },
      breadcrumbs: [ breadcrumb ]
    )

    described_class.call(event)

    expect(event.extra).to eq({ "api_key" => "[FILTERED]", "recipe_id" => 3 })
    expect(event.tags).to eq({ "token" => "[FILTERED]", "request_id" => "req-1" })
    expect(event.contexts).to eq({ "custom" => { "password" => "[FILTERED]" } })
    expect(breadcrumb.data).to eq({ "token" => "[FILTERED]", "request_id" => "req-1" })
  end

  it "returns the event even if scrubbing blows up" do
    event = build_event
    allow(Observability).to receive(:parameter_filter).and_raise("boom")

    expect(described_class.call(event)).to equal(event)
  end
end
