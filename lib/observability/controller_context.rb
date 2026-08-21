# frozen_string_literal: true

module Observability
  # Attaches the *current user id* - never the email or any other personal
  # detail - and the request id to log lines, Sentry breadcrumbs and the Sentry
  # user context.
  #
  # Included into ActionController::Base and ActionController::API from
  # config/initializers/observability.rb rather than written into
  # ApplicationController, so the observability layer stays self-contained.
  #
  # The context is applied twice: once before the callback chain (cheap, from
  # the session) and once in an `ensure` after it, by which time an API request
  # has been authenticated and `@current_user` is populated. The second pass
  # still runs before the exception reaches Sentry's middleware, so a failed
  # request is reported with its user id attached.
  module ControllerContext
    extend ActiveSupport::Concern

    included do
      prepend_around_action :with_observability_context
    end

    private

    def with_observability_context
      apply_observability_context
      add_observability_breadcrumb
      yield
    ensure
      apply_observability_context
    end

    def apply_observability_context
      user_id = observability_user_id
      return if user_id.nil?

      Current.user_id = user_id
      ::Sentry.set_user(id: user_id) if Observability.sentry_reporting?
    rescue StandardError => e
      Observability.report_instrumentation_error(e)
    end

    def add_observability_breadcrumb
      return unless Observability.sentry_reporting?

      ::Sentry.add_breadcrumb(
        ::Sentry::Breadcrumb.new(
          category: "request",
          level: "info",
          message: "#{self.class.name}##{action_name}",
          data: { request_id: Current.request_id, user_id: Current.user_id }.compact
        )
      )
    rescue StandardError => e
      Observability.report_instrumentation_error(e)
    end

    def observability_user_id
      current = instance_variable_defined?(:@current_user) ? @current_user : nil
      return current.id if current.respond_to?(:id)

      session[:user_id] if respond_to?(:session, true)
    rescue StandardError
      nil
    end
  end
end
