require 'rails_helper'

RSpec.describe SessionsController, type: :controller do
  describe 'GET #status' do
    context 'when the user is authenticated' do
      before do
        session[:authenticated] = true
        get :status
      end

      it 'returns a 200 OK status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns authenticated: true' do
        json_response = JSON.parse(response.body)
        expect(json_response['authenticated']).to be true
      end

      it 'returns JSON content type' do
        expect(response.content_type).to include('application/json')
      end

      it 'returns valid JSON' do
        expect { JSON.parse(response.body) }.not_to raise_error
      end

      it 'returns a JSON object with an authenticated key' do
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('authenticated')
      end
    end

    context 'when the user is not authenticated' do
      before do
        session[:authenticated] = false
        get :status
      end

      it 'returns a 200 OK status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns authenticated: false' do
        json_response = JSON.parse(response.body)
        expect(json_response['authenticated']).to be false
      end

      it 'returns JSON content type' do
        expect(response.content_type).to include('application/json')
      end

      it 'returns valid JSON' do
        expect { JSON.parse(response.body) }.not_to raise_error
      end

      it 'returns a JSON object with an authenticated key' do
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('authenticated')
      end
    end

    context 'when there is no existing session' do
      before do
        get :status
      end

      it 'returns a 200 OK status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns authenticated: false' do
        json_response = JSON.parse(response.body)
        expect(json_response['authenticated']).to be false
      end

      it 'returns JSON content type' do
        expect(response.content_type).to include('application/json')
      end

      it 'does not raise an error' do
        expect { get :status }.not_to raise_error
      end
    end

    context 'when session[:authenticated] is nil' do
      before do
        session[:authenticated] = nil
        get :status
      end

      it 'returns a 200 OK status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns authenticated: false' do
        json_response = JSON.parse(response.body)
        expect(json_response['authenticated']).to be false
      end
    end

    context 'response body' do
      before do
        get :status
      end

      it 'returns valid JSON' do
        expect { JSON.parse(response.body) }.not_to raise_error
      end

      it 'returns a JSON object with an authenticated key' do
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('authenticated')
      end

      it 'does not return an error key' do
        json_response = JSON.parse(response.body)
        expect(json_response).not_to have_key('error')
      end

      it 'does not return a message key' do
        json_response = JSON.parse(response.body)
        expect(json_response).not_to have_key('message')
      end
    end

    context 'skip_before_action' do
      it 'does not require authentication to access the status action' do
        expect(controller).not_to receive(:require_authentication)
        get :status
      end
    end

    context 'when called multiple times' do
      it 'returns a 200 OK status on each call' do
        get :status
        expect(response).to have_http_status(:ok)

        get :status
        expect(response).to have_http_status(:ok)
      end

      it 'reflects the current session state on each call' do
        session[:authenticated] = false
        get :status
        json_response = JSON.parse(response.body)
        expect(json_response['authenticated']).to be false

        session[:authenticated] = true
        get :status
        json_response = JSON.parse(response.body)
        expect(json_response['authenticated']).to be true
      end
    end

    context 'authenticated? helper' do
      it 'calls the authenticated? helper method' do
        expect(controller).to receive(:authenticated?).and_call_original
        get :status
      end

      context 'when authenticated? returns true' do
        before do
          allow(controller).to receive(:authenticated?).and_return(true)
          get :status
        end

        it 'returns authenticated: true' do
          json_response = JSON.parse(response.body)
          expect(json_response['authenticated']).to be true
        end

        it 'returns a 200 OK status' do
          expect(response).to have_http_status(:ok)
        end
      end

      context 'when authenticated? returns false' do
        before do
          allow(controller).to receive(:authenticated?).and_return(false)
          get :status
        end

        it 'returns authenticated: false' do
          json_response = JSON.parse(response.body)
          expect(json_response['authenticated']).to be false
        end

        it 'returns a 200 OK status' do
          expect(response).to have_http_status(:ok)
        end
      end
    end

    context 'after logging in' do
      before do
        session[:authenticated] = true
        get :status
      end

      it 'returns authenticated: true' do
        json_response = JSON.parse(response.body)
        expect(json_response['authenticated']).to be true
      end
    end

    context 'after logging out' do
      before do
        session[:authenticated] = true
        delete :destroy
        get :status
      end

      it 'returns a 200 OK status' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns authenticated: false' do
        json_response = JSON.parse(response.body)
        expect(json_response['authenticated']).to be false
      end
    end
  end
end
