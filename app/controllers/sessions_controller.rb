class SessionsController < ApplicationController
  skip_before_action :require_authentication, only: [:create, :status, :destroy]
  skip_before_action :verify_authenticity_token

  # POST /auth/login
  def create
    site_password = Rails.application.credentials.dig(:site_password) || ENV['SITE_PASSWORD']

    if site_password.blank?
      render json: { error: 'Authentication not configured' }, status: :internal_server_error
      return
    end

    if params[:password] == site_password
      session[:authenticated] = true
      render json: { message: 'Login successful' }, status: :ok
    else
      render json: { error: 'Invalid password' }, status: :unauthorized
    end
  end

  # DELETE /auth/logout
  def destroy
    session[:authenticated] = false
    reset_session
    render json: { message: 'Logged out successfully' }, status: :ok
  end

  # GET /auth/status
  def status
    if authenticated?
      render json: { authenticated: true }, status: :ok
    else
      render json: { authenticated: false }, status: :ok
    end
  end
end
