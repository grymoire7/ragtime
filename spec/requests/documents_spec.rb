require 'rails_helper'

RSpec.describe "Documents", type: :request do
  # Explicitly clean up documents before each test to avoid persisting data
  before(:each) do
    Document.destroy_all
    authenticate_request
  end

  describe "GET /documents" do
    it "returns all documents" do
      doc1 = create(:document, title: "Document 1")
      doc2 = create(:document, title: "Document 2")

      get documents_path

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json.length).to eq(2)
      expect(json.map { |d| d["title"] }).to contain_exactly("Document 1", "Document 2")
    end

    it "returns documents ordered by created_at desc" do
      old_doc = create(:document, title: "Old", created_at: 2.days.ago)
      new_doc = create(:document, title: "New", created_at: 1.day.ago)

      get documents_path

      json = JSON.parse(response.body)
      expect(json.first["title"]).to eq("New")
      expect(json.last["title"]).to eq("Old")
    end

    it "includes document metadata" do
      document = create(:document)

      get documents_path

      json = JSON.parse(response.body)
      doc_json = json.first

      expect(doc_json).to have_key("id")
      expect(doc_json).to have_key("title")
      expect(doc_json).to have_key("filename")
      expect(doc_json).to have_key("content_type")
      expect(doc_json).to have_key("file_size")
      expect(doc_json).to have_key("status")
      expect(doc_json).to have_key("created_at")
      expect(doc_json).to have_key("chunk_count")
      expect(doc_json).to have_key("error_message")
    end

    it "includes error_message for failed documents" do
      failed_doc = create(:document, status: :failed, error_message: "Processing failed")

      get documents_path

      json = JSON.parse(response.body)
      doc_json = json.first

      expect(doc_json["status"]).to eq("failed")
      expect(doc_json["error_message"]).to eq("Processing failed")
    end

    it "includes chunk count" do
      document = create(:document, :with_chunks)

      get documents_path

      json = JSON.parse(response.body)
      expect(json.first["chunk_count"]).to eq(3)
    end

    it "returns empty array when no documents exist" do
      get documents_path

      json = JSON.parse(response.body)
      expect(json).to eq([])
    end
  end

  describe "GET /documents/:id" do
    let(:document) { create(:document, :with_chunks) }

    it "returns the document with its chunks" do
      get document_path(document)

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json["id"]).to eq(document.id)
      expect(json["title"]).to eq(document.title)
      expect(json["chunks"]).to be_an(Array)
      expect(json["chunks"].length).to eq(3)
    end

    it "includes chunk details" do
      get document_path(document)

      json = JSON.parse(response.body)
      chunk_json = json["chunks"].first

      expect(chunk_json).to have_key("id")
      expect(chunk_json).to have_key("content")
      expect(chunk_json).to have_key("position")
      expect(chunk_json).to have_key("token_count")
    end

    it "includes error_message in response" do
      failed_doc = create(:document, status: :failed, error_message: "Extraction failed")

      get document_path(failed_doc)

      json = JSON.parse(response.body)
      expect(json).to have_key("error_message")
      expect(json["error_message"]).to eq("Extraction failed")
    end

    it "orders chunks by position" do
      get document_path(document)

      json = JSON.parse(response.body)
      positions = json["chunks"].map { |c| c["position"] }

      expect(positions).to eq(positions.sort)
    end

    context "when document does not exist" do
      it "returns 404" do
        get document_path(id: 99999)

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Document not found")
      end
    end
  end

  describe "POST /documents" do
    let(:file) { fixture_file_upload('spec/fixtures/files/test.txt', 'text/plain') }

    before do
      # Create the fixtures directory and file if they don't exist
      FileUtils.mkdir_p(Rails.root.join('spec', 'fixtures', 'files'))
      File.write(Rails.root.join('spec', 'fixtures', 'files', 'test.txt'), 'Test file content')

      # Mock the background job
      allow(ProcessDocumentJob).to receive(:perform_later)
    end

    it "creates a new document" do
      expect {
        post documents_path, params: { file: file, title: "Test Document" }
      }.to change(Document, :count).by(1)

      expect(response).to have_http_status(:created)
    end

    it "attaches the uploaded file" do
      post documents_path, params: { file: file }

      document = Document.last
      expect(document.file).to be_attached
    end

    it "sets document attributes from file" do
      post documents_path, params: { file: file, title: "Custom Title" }

      document = Document.last
      expect(document.title).to eq("Custom Title")
      expect(document.filename).to eq("test.txt")
      expect(document.content_type).to eq("text/plain")
      expect(document.file_size).to be > 0
      expect(document.status).to eq("pending")
    end

    it "uses filename as title if not provided" do
      post documents_path, params: { file: file }

      document = Document.last
      expect(document.title).to eq("test.txt")
    end

    it "enqueues ProcessDocumentJob" do
      post documents_path, params: { file: file }

      document = Document.last
      expect(ProcessDocumentJob).to have_received(:perform_later).with(document.id)
    end

    it "returns document JSON" do
      post documents_path, params: { file: file }

      json = JSON.parse(response.body)
      expect(json).to have_key("id")
      expect(json).to have_key("title")
      expect(json).to have_key("status")
      expect(json["status"]).to eq("pending")
    end

    context "when no file is provided" do
      it "returns 422 with error" do
        post documents_path, params: {}

        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("No file provided")
      end
    end

    context "when document is invalid" do
      it "returns 422 with errors" do
        # Force validation error by stubbing save to return false
        allow_any_instance_of(Document).to receive(:save).and_return(false)
        allow_any_instance_of(Document).to receive_message_chain(:errors, :full_messages)
          .and_return(["Title can't be blank"])

        post documents_path, params: { file: file }

        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body)
        expect(json["errors"]).to include("Title can't be blank")
      end
    end
  end

  describe "DELETE /documents/:id" do
    let!(:document) { create(:document, :with_chunks) }

    it "deletes the document" do
      expect {
        delete document_path(document)
      }.to change(Document, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it "deletes associated chunks" do
      chunk_ids = document.chunks.pluck(:id)

      delete document_path(document)

      chunk_ids.each do |chunk_id|
        expect(Chunk.exists?(chunk_id)).to be false
      end
    end

    it "returns 204 with no content" do
      delete document_path(document)

      expect(response).to have_http_status(:no_content)
      expect(response.body).to be_empty
    end

    context "when document does not exist" do
      it "returns 404" do
        delete document_path(id: 99999)

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Document not found")
      end
    end
  end
end
