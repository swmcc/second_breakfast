# frozen_string_literal: true

# Error tracking and performance tracing via Sentry.
#
# This file is a deliberate no-op unless ENV["SENTRY_DSN"] is present: without
# a DSN `Sentry.init` is never called, the SDK stays uninitialised, and nothing
# is captured or transmitted. That keeps development, test and CI completely
# offline while production activates the moment the DSN is supplied.
#
# To turn it on the owner needs a Sentry account (sentry.io or self-hosted),
# a project of platform "Ruby / Rails", and its DSN exported as SENTRY_DSN.
# See config/deploy.yml - Kamal already passes the variable through.
#
# Optional:
#   SENTRY_ENVIRONMENT        override the reported environment (default Rails.env)
#   SENTRY_RELEASE            release/version string, e.g. the git SHA
#   SENTRY_TRACES_SAMPLE_RATE performance tracing sample rate (default 0.05)
#
# Alerting (issue #68's "configure alerts for critical errors") is configured in
# the Sentry UI, not here - see the PR notes.

if Observability.sentry_enabled?
  Sentry.init do |config|
    config.dsn = ENV["SENTRY_DSN"]
    config.environment = ENV.fetch("SENTRY_ENVIRONMENT", Rails.env.to_s)
    config.release = ENV["SENTRY_RELEASE"] if ENV["SENTRY_RELEASE"].present?

    # Breadcrumbs for debugging: Rails instrumentation plus outbound HTTP.
    config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]

    # --- PII ---------------------------------------------------------------
    # Never send request bodies, cookies, headers or IP addresses by default...
    config.send_default_pii = false
    # ...and scrub password / password_confirmation / token / api_key /
    # authorization out of anything that is left (extra, tags, contexts,
    # breadcrumbs), reducing the user context to an id.
    config.before_send = Observability::SentryScrubber.method(:call)
    config.before_send_transaction = Observability::SentryScrubber.method(:call)

    # --- Performance -------------------------------------------------------
    # Conservative by default: 5% of requests are traced. Sentry's tracing is
    # the APM story here; no New Relic/Scout agent is installed.
    config.traces_sample_rate = Observability.traces_sample_rate

    # Noise we do not want paging anyone.
    config.excluded_exceptions += [
      "ActionController::BadRequest",
      "ActionController::UnknownFormat",
      "ActionDispatch::Http::MimeNegotiation::InvalidType"
    ]
  end
end
