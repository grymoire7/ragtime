class ApplicationController < ActionController::Base
  # Skip CSRF verification for JSON API requests from the Vue frontend
  # HTML requests will still have CSRF protection
  protect_from_forgery with: :exception, unless: -> { request.format.json? }

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Require authentication for all actions unless skipped
  before_action :require_authentication

  private

  def authenticated?
    session[:authenticated] == true
  end

  def require_authentication
    unless authenticated?
      render json: { error: 'Authentication required' }, status: :unauthorized
    end
  end
end
