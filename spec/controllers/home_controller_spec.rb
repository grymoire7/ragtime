# frozen_string_literal: true

require 'rails_helper'

RSpec.describe HomeController, type: :controller do
  describe 'GET #index' do
    context 'redirect behavior' do
      it 'returns a moved permanently (301) status' do
        get :index
        expect(response).to have_http_status(:moved_permanently)
      end

      it 'redirects to the frontend path' do
        get :index
        expect(response).to redirect_to(/\/frontend\//)
      end

      it 'redirects to the correct full URL with protocol and host' do
        get :index
        expect(response.location).to include('/frontend/')
      end

      it 'preserves the protocol in the redirect URL' do
        get :index
        expect(response.location).to start_with('http')
      end

      it 'preserves the host in the redirect URL' do
        get :index
        expect(response.location).to include(request.host)
      end

      it 'redirects to the frontend with trailing slash' do
        get :index
        expect(response.location).to end_with('/frontend/')
      end
    end

    context 'authentication' do
      it 'does not require authentication' do
        # Simulate that require_authentication would raise or redirect if called
        # Since skip_before_action is used, the action should succeed without auth
        allow(controller).to receive(:require_authentication) do
          controller.redirect_to('/login')
        end

        get :index

        expect(response).to have_http_status(:moved_permanently)
        expect(response.location).to include('/frontend/')
      end

      it 'skips the require_authentication before action' do
        expect(controller).not_to receive(:require_authentication)
        get :index
      end
    end

    context 'with different host configurations' do
      it 'includes the host with port in the redirect URL' do
        get :index
        expect(response.location).to include(request.host_with_port)
      end

      it 'constructs the URL using request protocol and host_with_port' do
        expected_url = "#{request.protocol}#{request.host_with_port}/frontend/"
        get :index
        expect(response.location).to eq(expected_url)
      end
    end

    context 'response headers' do
      it 'sets the Location header in the response' do
        get :index
        expect(response.headers['Location']).to be_present
      end

      it 'sets the Location header to the frontend URL' do
        get :index
        expect(response.headers['Location']).to include('/frontend/')
      end
    end
  end
end
