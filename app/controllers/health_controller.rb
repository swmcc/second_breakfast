# frozen_string_literal: true

# Deep health check.
#
# Rails' built-in `/up` (rails/health#show) only proves the process booted and
# can render - it never touches the database. `/health` additionally verifies
# database connectivity, which is what a Kamal deploy gate or an uptime monitor
# actually wants to know.
#
# Inherits from ActionController::Base rather than ApplicationController so the
# `allow_browser versions: :modern` gate does not reject monitoring agents,
# which do not send browser user agents.
class HealthController < ActionController::Base
  def show
    checks = { database: database_ok? }
    healthy = checks.values.all?

    render json: {
      status: healthy ? "ok" : "error",
      checks: checks,
      request_id: request.request_id,
      timestamp: Time.current.iso8601
    }, status: healthy ? :ok : :service_unavailable
  end

  private

  def database_ok?
    ActiveRecord::Base.with_connection { |connection| connection.select_value("SELECT 1") }.to_i == 1
  rescue StandardError => e
    Rails.logger.error({ event: "health_check_failed", check: "database", error: e.class.name })
    false
  end
end
