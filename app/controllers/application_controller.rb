class ApplicationController < ActionController::Base
  # Skip CSRF protection for API requests (using null_session strategy)
  # This allows the Vue frontend to make requests without CSRF tokens
  protect_from_forgery with: :null_session

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
end
