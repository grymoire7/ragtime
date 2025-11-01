require 'rails_helper'

RSpec.describe "Chats", type: :request do
  before(:each) do
    Chat.destroy_all
    Model.destroy_all
  end

  let!(:gemma_model) { create(:model, :gemma3) }
  let!(:test_default_model) { create(:model, model_id: 'test-chat-model', name: 'Test Chat Model', provider: 'test') }

  describe "GET /chats" do
    it "returns all chats" do
      chat1 = create(:chat, model: gemma_model)
      chat2 = create(:chat, model: gemma_model)

      get chats_path

      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /chats/new" do
    it "returns success" do
      get new_chat_path

      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /chats" do
    it "creates a new chat with JSON format" do
      expect {
        post chats_path,
          params: { chat: { model: gemma_model.model_id } },
          headers: { 'Accept' => 'application/json' }
      }.to change(Chat, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["id"]).to be_present
    end

    it "creates a chat with default model when no model provided" do
      expect {
        post chats_path,
          headers: { 'Accept' => 'application/json' }
      }.to change(Chat, :count).by(1)

      expect(response).to have_http_status(:created)

      # Verify it used the test environment's default model
      chat = Chat.last
      expect(chat.model).to eq(test_default_model)
    end

    it "returns error for invalid model" do
      post chats_path,
        params: { chat: { model: "invalid-model" } },
        headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json["error"]).to include("Model not found")
    end

    it "enqueues ChatResponseJob when prompt is provided" do
      allow(ChatResponseJob).to receive(:perform_later)

      post chats_path,
        params: { chat: { model: gemma_model.model_id, prompt: "Hello" } },
        headers: { 'Accept' => 'application/json' }

      chat = Chat.last
      expect(ChatResponseJob).to have_received(:perform_later).with(chat.id, "Hello")
    end
  end

  describe "GET /chats/:id" do
    let(:chat) { create(:chat, model: gemma_model) }

    it "returns the chat as HTML" do
      get chat_path(chat)

      expect(response).to have_http_status(:success)
    end

    it "returns the chat as JSON" do
      get chat_path(chat), headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json["id"]).to eq(chat.id)
      expect(json["messages"]).to be_an(Array)
      expect(json["model"]).to be_present
      expect(json["created_at"]).to be_present
    end

    it "includes message details in JSON response" do
      user_msg = create(:message, :user_message, chat: chat, content: "Hello")
      assistant_msg = create(:message, :assistant_message, chat: chat, content: "Hi there")

      get chat_path(chat), headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      messages = json["messages"]

      expect(messages.length).to eq(2)

      first_message = messages.first
      expect(first_message["id"]).to be_present
      expect(first_message["role"]).to be_present
      expect(first_message["content"]).to be_present
      expect(first_message["created_at"]).to be_present
    end

    it "does not include unsaved messages in JSON response" do
      create(:message, chat: chat, content: "Saved message")

      # Build an unsaved message
      chat.messages.build(role: 'user', content: 'unsaved')

      get chat_path(chat), headers: { 'Accept' => 'application/json' }

      json = JSON.parse(response.body)
      messages = json["messages"]

      # Should only include saved messages
      expect(messages.length).to eq(1)
      expect(messages.any? { |m| m["content"] == "unsaved" }).to be false
    end
  end
end
