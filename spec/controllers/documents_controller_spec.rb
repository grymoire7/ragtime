require 'rails_helper'

RSpec.describe DocumentsController, type: :controller do
  describe '#set_document' do
    let(:document) do
      Document.create!(
        title: 'Test Document',
        filename: 'test.pdf',
        content_type: 'application/pdf',
        file_size: 1024,
        status: :pending
      )
    end

    context 'when accessed via GET #show' do
      context 'when the document exists' do
        before do
          session[:authenticated] = true
          get :show, params: { id: document.id }
        end

        it 'returns a successful response' do
          expect(response).to have_http_status(:ok)
        end

        it 'sets @document to the correct document' do
          expect(JSON.parse(response.body)['id']).to eq(document.id)
        end

        it 'sets @document with the correct id' do
          expect(JSON.parse(response.body)['id']).to eq(document.id)
        end

        it 'sets @document with the correct title' do
          expect(JSON.parse(response.body)['title']).to eq('Test Document')
        end

        it 'sets @document with the correct filename' do
          expect(JSON.parse(response.body)['filename']).to eq('test.pdf')
        end

        it 'sets @document with the correct content_type' do
          expect(JSON.parse(response.body)['content_type']).to eq('application/pdf')
        end

        it 'sets @document with the correct file_size' do
          expect(JSON.parse(response.body)['file_size']).to eq(1024)
        end

        it 'sets @document with the correct status' do
          expect(JSON.parse(response.body)['status']).to eq('pending')
        end

        it 'returns JSON content' do
          json_response = JSON.parse(response.body)
          expect(json_response).to be_a(Hash)
        end

        it 'returns the document id in the response' do
          json_response = JSON.parse(response.body)
          expect(json_response['id']).to eq(document.id)
        end

        it 'returns the document title in the response' do
          json_response = JSON.parse(response.body)
          expect(json_response['title']).to eq('Test Document')
        end

        it 'returns the document filename in the response' do
          json_response = JSON.parse(response.body)
          expect(json_response['filename']).to eq('test.pdf')
        end
      end

      context 'when the document does not exist' do
        before do
          session[:authenticated] = true
          get :show, params: { id: 99999 }
        end

        it 'returns a not found status' do
          expect(response).to have_http_status(:not_found)
        end

        it 'returns an error message' do
          json_response = JSON.parse(response.body)
          expect(json_response['error']).to eq('Document not found')
        end

        it 'does not return a document body' do
          expect(JSON.parse(response.body)).not_to have_key('id')
        end

        it 'returns JSON content type' do
          expect(response.content_type).to include('application/json')
        end
      end

      context 'when the document id is a string that does not match any record' do
        before do
          session[:authenticated] = true
          get :show, params: { id: 'nonexistent' }
        end

        it 'returns a not found status' do
          expect(response).to have_http_status(:not_found)
        end

        it 'returns an error message' do
          json_response = JSON.parse(response.body)
          expect(json_response['error']).to eq('Document not found')
        end
      end
    end

    context 'when accessed via DELETE #destroy' do
      context 'when the document exists' do
        before do
          session[:authenticated] = true
          delete :destroy, params: { id: document.id }
        end

        it 'returns a no content status' do
          expect(response).to have_http_status(:no_content)
        end

        it 'sets @document to the correct document before destroying' do
          expect(Document.exists?(document.id)).to be false
        end
      end

      context 'when the document does not exist' do
        before do
          session[:authenticated] = true
          delete :destroy, params: { id: 99999 }
        end

        it 'returns a not found status' do
          expect(response).to have_http_status(:not_found)
        end

        it 'returns an error message' do
          json_response = JSON.parse(response.body)
          expect(json_response['error']).to eq('Document not found')
        end

        it 'does not return a document body' do
          expect(JSON.parse(response.body)).not_to have_key('id')
        end
      end
    end

    context 'with multiple documents in the database' do
      let!(:document1) do
        Document.create!(
          title: 'First Document',
          filename: 'first.pdf',
          content_type: 'application/pdf',
          file_size: 512,
          status: :pending
        )
      end

      let!(:document2) do
        Document.create!(
          title: 'Second Document',
          filename: 'second.pdf',
          content_type: 'application/pdf',
          file_size: 2048,
          status: :completed
        )
      end

      it 'sets @document to the correct document when requesting document1' do
        session[:authenticated] = true
        get :show, params: { id: document1.id }
        expect(JSON.parse(response.body)['id']).to eq(document1.id)
      end

      it 'sets @document to the correct document when requesting document2' do
        session[:authenticated] = true
        get :show, params: { id: document2.id }
        expect(JSON.parse(response.body)['id']).to eq(document2.id)
      end

      it 'returns the correct title for document1' do
        session[:authenticated] = true
        get :show, params: { id: document1.id }
        json_response = JSON.parse(response.body)
        expect(json_response['title']).to eq('First Document')
      end

      it 'returns the correct title for document2' do
        session[:authenticated] = true
        get :show, params: { id: document2.id }
        json_response = JSON.parse(response.body)
        expect(json_response['title']).to eq('Second Document')
      end
    end

    context 'when the document has associated chunks' do
      let(:document_with_chunks) do
        Document.create!(
          title: 'Document with Chunks',
          filename: 'chunked.pdf',
          content_type: 'application/pdf',
          file_size: 4096,
          status: :completed
        )
      end

      before do
        session[:authenticated] = true
        get :show, params: { id: document_with_chunks.id }
      end

      it 'returns a successful response' do
        expect(response).to have_http_status(:ok)
      end

      it 'sets @document to the correct document' do
        expect(JSON.parse(response.body)['id']).to eq(document_with_chunks.id)
      end

      it 'returns chunks in the response' do
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('chunks')
      end
    end
  end
end
