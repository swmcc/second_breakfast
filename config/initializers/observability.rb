# frozen_string_literal: true

# Observability wiring. The library itself lives in lib/observability.rb and is
# required from config/application.rb.
#
# Everything here is opt-in through ENV:
#
#   OBSERVABILITY_ENABLED  attach the notification subscribers (default: on in
#                          production only, so local development and the test
#                          suite stay quiet)
#   RAILS_LOG_FORMAT       "json" (default in production) or "text"
#   RAILS_LOG_LEVEL        standard Rails log level (default "info" in production)
#   SLOW_REQUEST_MS        warn above this request duration in ms (default 1000)
#   SLOW_QUERY_MS          warn above this SQL duration in ms (default 500)
#
# Deleting this file plus lib/observability* removes the whole layer.

Rails.application.config.after_initialize do
  next unless Observability.enabled?

  # One structured line per request instead of Rails' Processing/Completed
  # pair. Only silence the default subscriber when we are actually emitting
  # JSON, so RAILS_LOG_FORMAT=text keeps the familiar output.
  Observability::RequestLogSubscriber.silence_default_controller_logging! if Observability.json_logging?
  Observability::RequestLogSubscriber.attach!

  # Slow request / slow SQL warnings - the self-hosted stand-in for an APM.
  Observability::PerformanceSubscriber.attach!

  # `metric` log lines for recipe created / recipe viewed / search performed.
  Observability::MetricsSubscriber.attach!
end

# Current user id (never the email) + request id on log lines, Sentry
# breadcrumbs and the Sentry user context.
ActiveSupport.on_load(:action_controller) do
  include Observability::ControllerContext
end
