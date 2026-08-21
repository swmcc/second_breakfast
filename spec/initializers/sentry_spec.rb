require "rails_helper"

# No network is touched here: the point of these specs is that without a DSN
# Sentry is never initialised, so nothing can be transmitted from dev/test/CI.
RSpec.describe "config/initializers/sentry.rb" do
  let(:initializer) { Rails.root.join("config/initializers/sentry.rb") }

  around do |example|
    original = ENV["SENTRY_DSN"]
    example.run
  ensure
    ENV["SENTRY_DSN"] = original
  end

  it "leaves Sentry uninitialised in the test suite" do
    expect(ENV["SENTRY_DSN"]).to be_blank
    expect(Sentry.initialized?).to be(false)
  end

  it "is a no-op when no DSN is configured" do
    ENV.delete("SENTRY_DSN")

    expect(Sentry).not_to receive(:init)

    load initializer
  end

  it "is a no-op when the DSN is blank" do
    ENV["SENTRY_DSN"] = ""

    expect(Sentry).not_to receive(:init)

    load initializer
  end

  it "configures Sentry as soon as a DSN is supplied" do
    ENV["SENTRY_DSN"] = "https://public@example.invalid/1"
    captured = nil
    allow(Sentry).to receive(:init) { |&block| captured = block }

    load initializer

    expect(Sentry).to have_received(:init)

    config = Sentry::Configuration.new
    captured.call(config)

    expect(config.dsn.to_s).to include("example.invalid")
    expect(config.environment).to eq("test")
    expect(config.send_default_pii).to be(false)
    expect(config.traces_sample_rate).to eq(Observability::DEFAULT_TRACES_SAMPLE_RATE)
    expect(config.before_send).to eq(Observability::SentryScrubber.method(:call))
    expect(config.before_send_transaction).to eq(Observability::SentryScrubber.method(:call))
  end
end
