# frozen_string_literal: true

module Observability
  # Copies the request id that `ActionDispatch::RequestId` generated into
  # `Observability::Current` so every log line and Sentry event can carry it.
  #
  # Inserted *after* `ActionDispatch::Executor` (see config/application.rb)
  # because the executor is what resets `CurrentAttributes` between requests.
  #
  # `ActionDispatch::RequestId` already echoes the id back to the client in the
  # `X-Request-Id` response header, so nothing extra is needed for tracing a
  # user-reported error back to a log line.
  class RequestContext
    def initialize(app)
      @app = app
    end

    def call(env)
      request_id = ActionDispatch::Request.new(env).request_id
      Current.request_id = request_id

      ::Sentry.configure_scope { |scope| scope.set_tags(request_id: request_id) } if Observability.sentry_reporting?

      @app.call(env)
    end
  end
end
