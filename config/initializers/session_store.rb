# frozen_string_literal: true

Rails.application.config.session_store :cookie_store,
  key: "_second_breakfast_session",
  expire_after: 2.weeks,
  httponly: true,
  same_site: :lax,
  secure: Rails.env.production?
