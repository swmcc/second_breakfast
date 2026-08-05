# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Additional browser security headers. X-Frame-Options, X-Content-Type-Options
# and X-XSS-Protection are already part of Rails' default headers, so they are
# not repeated here.
Rails.application.config.action_dispatch.default_headers["Referrer-Policy"] = "strict-origin-when-cross-origin"

# Rails' `config.permissions_policy` (see permissions_policy.rb) still emits the
# legacy `Feature-Policy` header, which current browsers ignore. Send the modern
# `Permissions-Policy` equivalent as well so the restrictions are actually enforced.
Rails.application.config.action_dispatch.default_headers["Permissions-Policy"] =
  "camera=(), gyroscope=(), microphone=(), usb=(), geolocation=()"
