require 'rails_helper'

RSpec.describe ChatsController, type: :controller do
  describe '#default_model' do
    let(:config_double) { double }
    let(:default_model_name) { 'gpt-4' }

    before do
      allow(Rails.application.config.x).to receive(:ruby_llm).and_return(config_double)
      allow(config_double).to receive(:[]).with(Rails.env.to_sym).and_return({ chat: { model: default_model_name } })
    end

    context 'when configuration is properly set' do
      it 'returns the model name from configuration' do
        expect(controller.send(:default_model)).to eq('gpt-4')
      end

      it 'returns a string value' do
        expect(controller.send(:default_model)).to be_a(String)
      end
    end

    context 'when the configured model name differs' do
      let(:default_model_name) { 'claude-3-opus' }

      it 'returns the configured model name' do
        expect(controller.send(:default_model)).to eq('claude-3-opus')
      end
    end

    context 'when used in create action as fallback' do
      let(:model_record) { instance_double(Model, id: 1, name: 'GPT-4', model_id: 'gpt-4') }
      let(:chat) { instance_double(Chat, id: 1, model: model_record, messages: double(build: double)) }

      before do
        session[:authenticated] = true
        allow(Model).to receive(:find_by).with(model_id: default_model_name).and_return(model_record)
        allow(Chat).to receive(:create!).and_return(chat)
        allow(chat).to receive(:as_json).and_return({ 'id' => 1 })
        allow(ChatResponseJob).to receive(:perform_later)
      end

      it 'uses default_model when no model param is provided' do
        expect(controller).to receive(:default_model).and_call_original
        post :create, params: { chat: {} }, format: :json
      end

      it 'creates a chat with the default model when no model param is given' do
        post :create, params: { chat: {} }, format: :json
        expect(Model).to have_received(:find_by).with(model_id: default_model_name)
      end

      it 'returns a successful response when using the default model' do
        post :create, params: { chat: {} }, format: :json
        expect(response).to have_http_status(:created)
      end

      it 'uses default_model when model param is blank' do
        post :create, params: { chat: { model: '' } }, format: :json
        expect(Model).to have_received(:find_by).with(model_id: default_model_name)
      end

      it 'uses default_model when model param is nil' do
        post :create, params: { chat: { model: nil } }, format: :json
        expect(Model).to have_received(:find_by).with(model_id: default_model_name)
      end

      context 'when the default model is not found in the database' do
        before do
          allow(Model).to receive(:find_by).with(model_id: default_model_name).and_return(nil)
        end

        it 'returns an error response' do
          post :create, params: { chat: {} }, format: :json
          expect(response).to have_http_status(:unprocessable_content)
        end

        it 'returns an error message indicating the model was not found' do
          post :create, params: { chat: {} }, format: :json
          json_response = JSON.parse(response.body)
          expect(json_response['error']).to include(default_model_name)
        end

        it 'does not create a chat' do
          post :create, params: { chat: {} }, format: :json
          expect(Chat).not_to have_received(:create!)
        end
      end

      context 'when a model param is provided' do
        let(:other_model_name) { 'claude-3-opus' }
        let(:other_model_record) { instance_double(Model, id: 2, name: 'Claude 3', model_id: other_model_name) }

        before do
          allow(Model).to receive(:find_by).with(model_id: other_model_name).and_return(other_model_record)
          allow(Chat).to receive(:create!).and_return(chat)
          allow(chat).to receive(:as_json).and_return({ 'id' => 1 })
        end

        it 'does not call default_model' do
          expect(controller).not_to receive(:default_model)
          post :create, params: { chat: { model: other_model_name } }, format: :json
        end

        it 'uses the provided model instead of the default' do
          post :create, params: { chat: { model: other_model_name } }, format: :json
          expect(Model).to have_received(:find_by).with(model_id: other_model_name)
        end
      end
    end
  end
end
