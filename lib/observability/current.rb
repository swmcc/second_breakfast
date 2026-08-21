# frozen_string_literal: true

module Observability
  # Per-request context that log lines and Sentry events are decorated with.
  #
  # Deliberately holds identifiers only - never an email address, name or any
  # other personally identifiable value.
  class Current < ActiveSupport::CurrentAttributes
    attribute :request_id, :user_id
  end
end
