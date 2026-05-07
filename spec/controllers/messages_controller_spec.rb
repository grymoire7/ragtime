require 'rails_helper'

RSpec.describe MessagesController, type: :controller do
  describe '#content' do
    let(:chat) { instance_double(Chat, id: 1) }

    before do
      session[:authenticated] = true
      allow(Chat).to receive(:find).with('1').and_return(chat)
      allow(Chat).to receive(:find).with(1).and_return(chat)
      allow(ChatResponseJob).to receive(:perform_later)
    end

    context 'when message content is a normal string' do
      it 'returns the content from params[:message][:content]' do
        post :create, params: { chat_id: 1, message: { content: 'Hello world' } }, format: :json
        expect(response).to have_http_status(:accepted)
      end

      it 'passes the correct content to ChatResponseJob' do
        expect(ChatResponseJob).to receive(:perform_later).with(chat.id, 'Hello world', {})
        post :create, params: { chat_id: 1, message: { content: 'Hello world' } }, format: :json
      end

      it 'passes a different content string to ChatResponseJob' do
        expect(ChatResponseJob).to receive(:perform_later).with(chat.id, 'Another message', {})
        post :create, params: { chat_id: 1, message: { content: 'Another message' } }, format: :json
      end

      it 'renders a JSON accepted response' do
        post :create, params: { chat_id: 1, message: { content: 'Hello world' } }, format: :json
        expect(response).to have_http_status(:accepted)
        expect(JSON.parse(response.body)).to eq({ 'message' => 'Message queued for processing' })
      end

      it 'uses the content from the message param to queue the job' do
        expect(ChatResponseJob).to receive(:perform_later).with(chat.id, 'Test content', {})
        post :create, params: { chat_id: 1, message: { content: 'Test content' } }, format: :json
      end
    end

    context 'when message content is blank' do
      it 'returns an error response for blank content' do
        post :create, params: { chat_id: 1, message: { content: '' } }, format: :json
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'returns an error message in JSON' do
        post :create, params: { chat_id: 1, message: { content: '' } }, format: :json
        expect(JSON.parse(response.body)).to eq({ 'error' => 'Content cannot be blank' })
      end

      it 'does not call ChatResponseJob when content is blank' do
        expect(ChatResponseJob).not_to receive(:perform_later)
        post :create, params: { chat_id: 1, message: { content: '' } }, format: :json
      end

      it 'returns an error response for nil content' do
        post :create, params: { chat_id: 1, message: { content: nil } }, format: :json
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'does not call ChatResponseJob when content is nil' do
        expect(ChatResponseJob).not_to receive(:perform_later)
        post :create, params: { chat_id: 1, message: { content: nil } }, format: :json
      end

      it 'returns an error response for whitespace-only content' do
        post :create, params: { chat_id: 1, message: { content: '   ' } }, format: :json
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'does not call ChatResponseJob when content is whitespace only' do
        expect(ChatResponseJob).not_to receive(:perform_later)
        post :create, params: { chat_id: 1, message: { content: '   ' } }, format: :json
      end
    end

    context 'when message content is a multi-word string' do
      it 'passes the full content string to ChatResponseJob' do
        expect(ChatResponseJob).to receive(:perform_later).with(chat.id, 'This is a longer message with multiple words', {})
        post :create, params: { chat_id: 1, message: { content: 'This is a longer message with multiple words' } }, format: :json
      end

      it 'renders accepted response' do
        post :create, params: { chat_id: 1, message: { content: 'This is a longer message with multiple words' } }, format: :json
        expect(response).to have_http_status(:accepted)
      end
    end

    context 'when message content contains special characters' do
      it 'passes content with special characters to ChatResponseJob' do
        special_content = 'Hello! How are you? 😊'
        expect(ChatResponseJob).to receive(:perform_later).with(chat.id, special_content, {})
        post :create, params: { chat_id: 1, message: { content: special_content } }, format: :json
      end

      it 'renders accepted response for content with special characters' do
        post :create, params: { chat_id: 1, message: { content: 'Hello! How are you? 😊' } }, format: :json
        expect(response).to have_http_status(:accepted)
      end
    end

    context 'when content is extracted correctly' do
      it 'reads from params[:message][:content] specifically' do
        expect(ChatResponseJob).to receive(:perform_later).with(chat.id, 'specific content', {})
        post :create, params: { chat_id: 1, message: { content: 'specific content' } }, format: :json
      end

      it 'does not use other param keys as content' do
        expect(ChatResponseJob).to receive(:perform_later).with(chat.id, 'correct content', {})
        post :create, params: { chat_id: 1, message: { content: 'correct content' }, other: 'ignored' }, format: :json
      end
    end
  end
end
