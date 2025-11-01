require 'rails_helper'

RSpec.describe "Messages", type: :request do
  before(:each) do
    Chat.destroy_all
    Model.destroy_all
  end

  let!(:gemma_model) { create(:model, :gemma3) }
  let(:chat) { create(:chat, model: gemma_model) }

  describe "POST /chats/:chat_id/messages" do
    it "creates a message with JSON format" do
      allow(ChatResponseJob).to receive(:perform_later)

      post chat_messages_path(chat),
        params: { message: { content: "What is the weather today?" } },
        headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:accepted)
      json = JSON.parse(response.body)
      expect(json["message"]).to eq("Message queued for processing")
    end

    it "enqueues ChatResponseJob with correct parameters" do
      content = "Tell me about Ruby on Rails"

      expect(ChatResponseJob).to receive(:perform_later).with(chat.id, content)

      post chat_messages_path(chat),
        params: { message: { content: content } },
        headers: { 'Accept' => 'application/json' }
    end

    it "returns error when content is blank" do
      post chat_messages_path(chat),
        params: { message: { content: "" } },
        headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["error"]).to include("cannot be blank")
    end

    it "returns error when content is nil" do
      post chat_messages_path(chat),
        params: { message: { content: nil } },
        headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["error"]).to include("cannot be blank")
    end

    it "returns error when content is whitespace-only" do
      post chat_messages_path(chat),
        params: { message: { content: "   " } },
        headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["error"]).to include("cannot be blank")
    end
  end
end
