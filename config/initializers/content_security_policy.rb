# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src     :self
    policy.font_src        :self, :data
    # Recipe images fetched from third-party sites may be served from external URLs.
    policy.img_src         :self, :data, :https
    policy.object_src      :none
    policy.script_src      :self
    # Trix (Action Text) and Tailwind inject inline styles at runtime.
    policy.style_src       :self, :unsafe_inline
    policy.connect_src     :self
    policy.frame_ancestors :none
    # Specify URI for violation reports
    # policy.report_uri "/csp-violation-report-endpoint"
  end

  # Generate session nonces for permitted importmap and inline scripts.
  # `javascript_importmap_tags` picks these up automatically.
  config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s.presence || SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[ script-src ]

  # Report violations without enforcing the policy.
  # config.content_security_policy_report_only = true
end

# The rswag Swagger UI mounted at /api-docs is a Rack app that renders inline
# scripts and supplies its own, looser CSP header. Under Rack 3 that header is
# capitalised while Rails looks for the lowercase name, so Rails does not detect
# it and would replace it with the app policy above — which blocks the inline
# bootstrap script and leaves the docs page blank. Drop the app policy for those
# requests so the engine's own header survives.
class SwaggerUiContentSecurityPolicyExemption
  PATH_PREFIX = "/api-docs"

  def initialize(app)
    @app = app
  end

  def call(env)
    if env["PATH_INFO"].to_s.start_with?(PATH_PREFIX)
      env[ActionDispatch::ContentSecurityPolicy::Request::POLICY] = nil
    end

    @app.call(env)
  end
end

Rails.application.config.middleware.insert_before(
  ActionDispatch::ContentSecurityPolicy::Middleware,
  SwaggerUiContentSecurityPolicyExemption
)
