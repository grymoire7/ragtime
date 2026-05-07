require 'rails_helper'

RSpec.describe ApplicationController, type: :controller do
  controller do
    def index
      render json: { success: true }
    end
  end

  before do
    routes.draw { get 'index' => 'anonymous#index' }
  end

  describe '#require_authentication' do
    context 'when user is authenticated' do
      before do
        session[:authenticated] = true
      end

      it 'allows the request to proceed' do
        get :index, format: :json
        expect(response).to have_http_status(:ok)
      end

      it 'renders the expected response body' do
        get :index, format: :json
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to eq(true)
      end

      it 'does not render an authentication error' do
        get :index, format: :json
        json_response = JSON.parse(response.body)
        expect(json_response).not_to have_key('error')
      end
    end

    context 'when user is not authenticated' do
      context 'when session[:authenticated] is false' do
        before do
          session[:authenticated] = false
        end

        it 'returns unauthorized status' do
          get :index, format: :json
          expect(response).to have_http_status(:unauthorized)
        end

        it 'renders an authentication error message' do
          get :index, format: :json
          json_response = JSON.parse(response.body)
          expect(json_response['error']).to eq('Authentication required')
        end

        it 'does not render the action response' do
          get :index, format: :json
          json_response = JSON.parse(response.body)
          expect(json_response).not_to have_key('success')
        end
      end

      context 'when session[:authenticated] is nil' do
        before do
          session[:authenticated] = nil
        end

        it 'returns unauthorized status' do
          get :index, format: :json
          expect(response).to have_http_status(:unauthorized)
        end

        it 'renders an authentication error message' do
          get :index, format: :json
          json_response = JSON.parse(response.body)
          expect(json_response['error']).to eq('Authentication required')
        end
      end

      context 'when session[:authenticated] is not set' do
        it 'returns unauthorized status' do
          get :index, format: :json
          expect(response).to have_http_status(:unauthorized)
        end

        it 'renders an authentication error message' do
          get :index, format: :json
          json_response = JSON.parse(response.body)
          expect(json_response['error']).to eq('Authentication required')
        end
      end

      context 'when session[:authenticated] is a truthy non-boolean value' do
        before do
          session[:authenticated] = 'true'
        end

        it 'returns unauthorized status because it uses strict equality with true' do
          get :index, format: :json
          expect(response).to have_http_status(:unauthorized)
        end

        it 'renders an authentication error message' do
          get :index, format: :json
          json_response = JSON.parse(response.body)
          expect(json_response['error']).to eq('Authentication required')
        end
      end

      context 'when session[:authenticated] is 1' do
        before do
          session[:authenticated] = 1
        end

        it 'returns unauthorized status because it uses strict equality with true' do
          get :index, format: :json
          expect(response).to have_http_status(:unauthorized)
        end

        it 'renders an authentication error message' do
          get :index, format: :json
          json_response = JSON.parse(response.body)
          expect(json_response['error']).to eq('Authentication required')
        end
      end

      context 'when session[:authenticated] is 0' do
        before do
          session[:authenticated] = 0
        end

        it 'returns unauthorized status' do
          get :index, format: :json
          expect(response).to have_http_status(:unauthorized)
        end

        it 'renders an authentication error message' do
          get :index, format: :json
          json_response = JSON.parse(response.body)
          expect(json_response['error']).to eq('Authentication required')
        end
      end

      context 'when session[:authenticated] is an empty string' do
        before do
          session[:authenticated] = ''
        end

        it 'returns unauthorized status' do
          get :index, format: :json
          expect(response).to have_http_status(:unauthorized)
        end

        it 'renders an authentication error message' do
          get :index, format: :json
          json_response = JSON.parse(response.body)
          expect(json_response['error']).to eq('Authentication required')
        end
      end
    end

    context 'response format' do
      context 'when not authenticated' do
        before do
          session[:authenticated] = false
        end

        it 'returns a JSON response' do
          get :index, format: :json
          expect(response.content_type).to include('application/json')
        end

        it 'returns a response with the error key' do
          get :index, format: :json
          json_response = JSON.parse(response.body)
          expect(json_response).to have_key('error')
        end

        it 'returns 401 HTTP status code' do
          get :index, format: :json
          expect(response.status).to eq(401)
        end
      end
    end
  end
end
