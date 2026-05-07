require 'rails_helper'

RSpec.describe ModelsController, type: :controller do
  describe 'POST #refresh' do
    context 'when refresh is successful' do
      before do
        session[:authenticated] = true
        allow(Model).to receive(:refresh!)
        post :refresh
      end

      it 'returns a redirect response' do
        expect(response).to be_redirect
      end

      it 'returns http status 302' do
        expect(response).to have_http_status(:found)
      end

      it 'redirects to models_path' do
        expect(response).to redirect_to(models_path)
      end

      it 'sets a success notice' do
        expect(flash[:notice]).to eq('Models refreshed successfully')
      end

      it 'calls Model.refresh!' do
        expect(Model).to have_received(:refresh!)
      end
    end

    context 'when verifying Model.refresh! is called' do
      before do
        session[:authenticated] = true
        allow(Model).to receive(:refresh!)
      end

      it 'calls Model.refresh! exactly once' do
        post :refresh
        expect(Model).to have_received(:refresh!).once
      end

      it 'calls Model.refresh! before redirecting' do
        post :refresh
        expect(Model).to have_received(:refresh!)
        expect(response).to redirect_to(models_path)
      end
    end

    context 'when Model.refresh! raises an error' do
      before do
        session[:authenticated] = true
        allow(Model).to receive(:refresh!).and_raise(StandardError, 'Refresh failed')
      end

      it 'raises a StandardError' do
        expect {
          post :refresh
        }.to raise_error(StandardError, 'Refresh failed')
      end
    end

    context 'when called multiple times' do
      before do
        session[:authenticated] = true
        allow(Model).to receive(:refresh!)
      end

      it 'calls Model.refresh! on each request' do
        post :refresh
        post :refresh
        expect(Model).to have_received(:refresh!).twice
      end
    end

    context 'when checking flash message content' do
      before do
        session[:authenticated] = true
        allow(Model).to receive(:refresh!)
        post :refresh
      end

      it 'does not set a flash alert' do
        expect(flash[:alert]).to be_nil
      end

      it 'sets the correct notice message' do
        expect(flash[:notice]).to eq('Models refreshed successfully')
      end
    end
  end
end
