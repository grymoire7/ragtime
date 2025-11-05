require 'rails_helper'

RSpec.describe "Sessions", type: :request do
  let(:site_password) { "test-password-123" }

  before do
    # Mock the credentials to return a test password
    # Use and_call_original to allow other credential lookups to work normally
    allow(Rails.application.credentials).to receive(:dig).and_call_original
    allow(Rails.application.credentials).to receive(:dig).with(:site_password).and_return(site_password)
  end

  describe "POST /auth/login" do
    context "with correct password" do
      it "authenticates and sets session" do
        post "/auth/login", params: { password: site_password }, as: :json

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)["message"]).to eq("Login successful")
        expect(session[:authenticated]).to eq(true)
      end
    end

    context "with incorrect password" do
      it "returns unauthorized error" do
        post "/auth/login", params: { password: "wrong-password" }, as: :json

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)["error"]).to eq("Invalid password")
        expect(session[:authenticated]).to be_nil
      end
    end

    context "when site password is not configured" do
      before do
        allow(Rails.application.credentials).to receive(:dig).and_call_original
        allow(Rails.application.credentials).to receive(:dig).with(:site_password).and_return(nil)
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('SITE_PASSWORD').and_return(nil)
      end

      it "returns internal server error" do
        post "/auth/login", params: { password: "any-password" }, as: :json

        expect(response).to have_http_status(:internal_server_error)
        expect(JSON.parse(response.body)["error"]).to eq("Authentication not configured")
      end
    end
  end

  describe "DELETE /auth/logout" do
    context "when authenticated" do
      before do
        post "/auth/login", params: { password: site_password }, as: :json
      end

      it "logs out and clears session" do
        delete "/auth/logout", as: :json

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)["message"]).to eq("Logged out successfully")
        expect(session[:authenticated]).to be_falsey
      end
    end

    context "when not authenticated" do
      it "returns success anyway (idempotent)" do
        delete "/auth/logout", as: :json

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)["message"]).to eq("Logged out successfully")
      end
    end
  end

  describe "GET /auth/status" do
    context "when authenticated" do
      before do
        post "/auth/login", params: { password: site_password }, as: :json
      end

      it "returns authenticated true" do
        get "/auth/status", as: :json

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)["authenticated"]).to eq(true)
      end
    end

    context "when not authenticated" do
      it "returns authenticated false" do
        get "/auth/status", as: :json

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)["authenticated"]).to eq(false)
      end
    end
  end

  describe "protected endpoints" do
    describe "GET /documents" do
      context "when not authenticated" do
        it "returns unauthorized error" do
          get "/documents", as: :json

          expect(response).to have_http_status(:unauthorized)
          expect(JSON.parse(response.body)["error"]).to eq("Authentication required")
        end
      end

      context "when authenticated" do
        before do
          post "/auth/login", params: { password: site_password }, as: :json
        end

        it "allows access" do
          get "/documents", as: :json

          expect(response).to have_http_status(:ok)
        end
      end
    end

    describe "POST /chats" do
      context "when not authenticated" do
        it "returns unauthorized error" do
          post "/chats", as: :json

          expect(response).to have_http_status(:unauthorized)
          expect(JSON.parse(response.body)["error"]).to eq("Authentication required")
        end
      end

      context "when authenticated" do
        let!(:model) do
          Model.create!(
            model_id: "test-chat-model",
            name: "Test Chat Model",
            provider: "test"
          )
        end

        before do
          post "/auth/login", params: { password: site_password }, as: :json
        end

        it "allows access" do
          post "/chats", as: :json

          expect(response).to have_http_status(:created)
        end
      end
    end
  end

  describe "session persistence" do
    it "maintains authentication across requests" do
      # Login
      post "/auth/login", params: { password: site_password }, as: :json
      expect(response).to have_http_status(:ok)

      # Make subsequent request - should still be authenticated
      get "/documents", as: :json
      expect(response).to have_http_status(:ok)

      # Make another request
      get "/auth/status", as: :json
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["authenticated"]).to eq(true)

      # Logout
      delete "/auth/logout", as: :json
      expect(response).to have_http_status(:ok)

      # Subsequent request should be unauthorized
      get "/documents", as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "ENV variable fallback" do
    before do
      allow(Rails.application.credentials).to receive(:dig).and_call_original
      allow(Rails.application.credentials).to receive(:dig).with(:site_password).and_return(nil)
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('SITE_PASSWORD').and_return("env-password")
    end

    it "uses ENV variable when credentials are not set" do
      post "/auth/login", params: { password: "env-password" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["message"]).to eq("Login successful")
    end
  end
end
