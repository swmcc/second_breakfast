# frozen_string_literal: true

module Observability
  # Last line of defence before an event leaves the process for Sentry.
  #
  # `send_default_pii = false` already stops sentry-ruby attaching cookies,
  # request bodies and IP addresses, but anything we (or a gem) put in
  # `extra`, `tags`, `contexts` or a breadcrumb would still go out verbatim.
  # This runs every one of those through `ActiveSupport::ParameterFilter` with
  # the patterns in `Observability::SENSITIVE_KEY_PATTERNS` (password,
  # password_confirmation, token, api_key, authorization) and reduces the user
  # context to an id.
  module SentryScrubber
    # Signature matches Sentry's `before_send` / `before_send_transaction`.
    def self.call(event, _hint = nil)
      scrub_user(event)
      scrub_request(event)
      scrub_hash_attribute(event, :extra)
      scrub_hash_attribute(event, :tags)
      scrub_hash_attribute(event, :contexts)
      scrub_breadcrumbs(event)
      event
    rescue StandardError => e
      Observability.report_instrumentation_error(e)
      event
    end

    # Identifiers only - never email, name or IP.
    def self.scrub_user(event)
      return unless event.respond_to?(:user) && event.respond_to?(:user=)

      user = event.user
      return unless user.is_a?(Hash)

      event.user = user.select { |key, _| key.to_s == "id" }
    end

    def self.scrub_request(event)
      return unless event.respond_to?(:request)

      request = event.request
      return if request.nil?

      %i[data headers env].each do |attribute|
        next unless request.respond_to?(attribute) && request.respond_to?(:"#{attribute}=")

        value = request.public_send(attribute)
        request.public_send(:"#{attribute}=", filter(value)) if value.is_a?(Hash)
      end

      request.cookies = nil if request.respond_to?(:cookies=)

      return unless request.respond_to?(:query_string) && request.respond_to?(:query_string=)

      request.query_string = nil if sensitive?(request.query_string)
    end

    def self.scrub_hash_attribute(event, attribute)
      return unless event.respond_to?(attribute) && event.respond_to?(:"#{attribute}=")

      value = event.public_send(attribute)
      event.public_send(:"#{attribute}=", filter(value)) if value.is_a?(Hash)
    end

    def self.scrub_breadcrumbs(event)
      return unless event.respond_to?(:breadcrumbs)

      breadcrumbs = event.breadcrumbs
      return if breadcrumbs.nil? || !breadcrumbs.respond_to?(:each)

      breadcrumbs.each do |breadcrumb|
        next unless breadcrumb.respond_to?(:data) && breadcrumb.respond_to?(:data=)

        breadcrumb.data = filter(breadcrumb.data) if breadcrumb.data.is_a?(Hash)
      end
    end

    def self.filter(hash)
      Observability.parameter_filter.filter(hash)
    end

    def self.sensitive?(string)
      return false if string.blank?

      Observability::SENSITIVE_KEY_PATTERNS.any? { |pattern| string.to_s.match?(pattern) }
    end
  end
end
