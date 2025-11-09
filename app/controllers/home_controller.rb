# frozen_string_literal: true

class HomeController < ApplicationController
  # Skip authentication for root redirect - the Vue app handles its own routing and login
  skip_before_action :require_authentication, only: :index

  # Redirect root to Vue.js frontend, preserving protocol and port
  def index
    # Construct full URL to preserve protocol, host, and port
    redirect_to "#{request.protocol}#{request.host_with_port}/frontend/", status: :moved_permanently
  end
end
