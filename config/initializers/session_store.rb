# Configure session store for API authentication
# Using cookie store with same_site: :lax to allow cross-origin requests from Vue frontend
Rails.application.config.session_store :cookie_store,
  key: '_ragtime_session',
  same_site: :lax,
  secure: Rails.env.production?
