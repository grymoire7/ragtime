require 'rails_helper'

RSpec.describe ProcessDocumentJob, type: :job do
  let(:document) { create(:document) }
  let(:extracted_text) { "This is extracted text from the document. It has multiple sentences." }
  let(:chunk_data) do
    [
      { text: "Chunk 1 text", token_count: 10 },
      { text: "Chunk 2 text", token_count: 15 },
      { text: "Chunk 3 text", token_count: 12 }
    ]
  end
  let(:embeddings) do
    [
      Array.new(1536) { 0.1 },
      Array.new(1536) { 0.2 },
      Array.new(1536) { 0.3 }
    ]
  end

  before do
    allow(DocumentProcessing::TextExtractor).to receive(:extract).and_return(extracted_text)
    allow(DocumentProcessing::TextChunker).to receive(:chunk).and_return(chunk_data)
    allow(DocumentProcessing::EmbeddingGenerator).to receive(:generate_batch).and_return(embeddings)
  end

  describe "#perform" do
    it "updates document status to processing then completed" do
      described_class.new.perform(document.id)
      document.reload
      expect(document.status).to eq("completed")
    end

    it "extracts text from the document" do
      described_class.new.perform(document.id)

      expect(DocumentProcessing::TextExtractor).to have_received(:extract).with(document)
    end

    it "chunks the extracted text" do
      described_class.new.perform(document.id)

      expect(DocumentProcessing::TextChunker).to have_received(:chunk).with(extracted_text)
    end

    it "generates embeddings for all chunks" do
      described_class.new.perform(document.id)

      expect(DocumentProcessing::EmbeddingGenerator).to have_received(:generate_batch)
        .with(["Chunk 1 text", "Chunk 2 text", "Chunk 3 text"])
    end

    it "creates chunk records with correct data" do
      expect {
        described_class.new.perform(document.id)
      }.to change { document.chunks.count }.from(0).to(3)

      chunks = document.chunks.order(:position)

      expect(chunks[0].content).to eq("Chunk 1 text")
      expect(chunks[0].position).to eq(0)
      expect(chunks[0].token_count).to eq(10)
      expect(chunks[0].embedding.length).to eq(embeddings[0].length)
      chunks[0].embedding.each_with_index do |value, i|
        expect(value).to be_within(0.0001).of(embeddings[0][i])
      end

      expect(chunks[1].content).to eq("Chunk 2 text")
      expect(chunks[1].position).to eq(1)
      expect(chunks[1].token_count).to eq(15)

      expect(chunks[2].content).to eq("Chunk 3 text")
      expect(chunks[2].position).to eq(2)
      expect(chunks[2].token_count).to eq(12)
    end

    it "marks document as completed with timestamp" do
      before_time = Time.current
      described_class.new.perform(document.id)
      document.reload

      expect(document.status).to eq("completed")
      expect(document.processed_at).to be_within(1.second).of(before_time)
    end

    it "logs success message" do
      allow(Rails.logger).to receive(:info).and_call_original
      expect(Rails.logger).to receive(:info).with(/Successfully processed document/).and_call_original

      described_class.new.perform(document.id)
    end

    it "sets document status to processing before extracting text" do
      statuses_during_processing = []

      allow(DocumentProcessing::TextExtractor).to receive(:extract) do
        document.reload
        statuses_during_processing << document.status
        extracted_text
      end

      described_class.new.perform(document.id)

      expect(statuses_during_processing).to include("processing")
    end

    context "when extraction returns blank text" do
      before do
        allow(DocumentProcessing::TextExtractor).to receive(:extract).and_return("")
      end

      it "marks document as failed with error message" do
        expect {
          described_class.new.perform(document.id)
        }.to raise_error(ProcessDocumentJob::ProcessingError)

        document.reload
        expect(document.status).to eq("failed")
        expect(document.error_message).to eq("No text could be extracted from document")
      end

      it "logs error message" do
        allow(Rails.logger).to receive(:error)
        expect(Rails.logger).to receive(:error).with(/Failed to process document/)

        expect {
          described_class.new.perform(document.id)
        }.to raise_error(ProcessDocumentJob::ProcessingError)
      end

      it "logs backtrace" do
        allow(Rails.logger).to receive(:error)
        expect(Rails.logger).to receive(:error).with(anything).at_least(:twice)

        expect {
          described_class.new.perform(document.id)
        }.to raise_error(ProcessDocumentJob::ProcessingError)
      end

      it "re-raises the error" do
        expect {
          described_class.new.perform(document.id)
        }.to raise_error(ProcessDocumentJob::ProcessingError, "No text could be extracted from document")
      end

      it "does not create any chunks" do
        expect {
          described_class.new.perform(document.id)
        }.to raise_error(ProcessDocumentJob::ProcessingError)

        expect(document.chunks.count).to eq(0)
      end
    end

    context "when extraction returns nil" do
      before do
        allow(DocumentProcessing::TextExtractor).to receive(:extract).and_return(nil)
      end

      it "marks document as failed with error message" do
        expect {
          described_class.new.perform(document.id)
        }.to raise_error(ProcessDocumentJob::ProcessingError)

        document.reload
        expect(document.status).to eq("failed")
        expect(document.error_message).to eq("No text could be extracted from document")
      end
    end

    context "when chunking returns empty array" do
      before do
        allow(DocumentProcessing::TextChunker).to receive(:chunk).and_return([])
      end

      it "marks document as failed with error message" do
        expect {
          described_class.new.perform(document.id)
        }.to raise_error(ProcessDocumentJob::ProcessingError)

        document.reload
        expect(document.status).to eq("failed")
        expect(document.error_message).to eq("No chunks could be created from extracted text")
      end

      it "re-raises the error" do
        expect {
          described_class.new.perform(document.id)
        }.to raise_error(ProcessDocumentJob::ProcessingError, "No chunks could be created from extracted text")
      end

      it "does not attempt to generate embeddings" do
        expect {
          described_class.new.perform(document.id)
        }.to raise_error(ProcessDocumentJob::ProcessingError)

        expect(DocumentProcessing::EmbeddingGenerator).not_to have_received(:generate_batch)
      end
    end

    context "when text extraction raises ExtractionError" do
      let(:extraction_error) { DocumentProcessing::TextExtractor::ExtractionError.new("Extraction failed") }

      before do
        allow(DocumentProcessing::TextExtractor).to receive(:extract).and_raise(extraction_error)
      end

      it "marks document as failed with extraction error message" do
        expect {
          described_class.new.perform(document.id)
        }.to raise_error(DocumentProcessing::TextExtractor::ExtractionError)

        document.reload
        expect(document.status).to eq("failed")
        expect(document.error_message).to eq("Unable to extract text from document. The file may be corrupted or in an unsupported format.")
      end

      it "logs the error with class and message" do
        allow(Rails.logger).to receive(:error)
        expect(Rails.logger).to receive(:error).with(/Failed to process document.*ExtractionError/)

        expect {
          described_class.new.perform(document.id)
        }.to raise_error(DocumentProcessing::TextExtractor::ExtractionError)
      end

      it "logs the backtrace" do
        allow(Rails.logger).to receive(:error)
        backtrace_logged = false

        allow(Rails.logger).to receive(:error) do |msg|
          backtrace_logged = true if msg.is_a?(String) && !msg.match?(/Failed to process document/)
        end

        expect {
          described_class.new.perform(document.id)
        }.to raise_error(DocumentProcessing::TextExtractor::ExtractionError)

        expect(backtrace_logged).to be true
      end

      it "re-raises the error" do
        expect {
          described_class.new.perform(document.id)
        }.to raise_error(DocumentProcessing::TextExtractor::ExtractionError)
      end

      it "does not create any chunks" do
        expect {
          described_class.new.perform(document.id)
        }.to raise_error(DocumentProcessing::TextExtractor::ExtractionError)

        expect(document.chunks.count).to eq(0)
      end
    end

    context "when embedding generation fails" do
      let(:embedding_error) { DocumentProcessing::EmbeddingGenerator::EmbeddingError.new("API error") }

      before do
        allow(DocumentProcessing::EmbeddingGenerator).to receive(:generate_batch)
          .and_raise(embedding_error)
      end

      it "marks document as failed with generic error message" do
        expect {
          described_class.new.perform(document.id)
        }.to raise_error(DocumentProcessing::EmbeddingGenerator::EmbeddingError)

        document.reload
        expect(document.status).to eq("failed")
        expect(document.error_message).to include("An unexpected error occurred")
        expect(document.error_message).to include("EmbeddingError")
      end

      it "re-raises the error" do
        expect {
          described_class.new.perform(document.id)
        }.to raise_error(DocumentProcessing::EmbeddingGenerator::EmbeddingError)
      end

      it "does not create any chunks" do
        expect {
          described_class.new.perform(document.id)
        }.to raise_error(DocumentProcessing::EmbeddingGenerator::EmbeddingError)

        expect(document.chunks.count).to eq(0)
      end
    end

    context "when an unexpected StandardError occurs" do
      let(:unexpected_error) { StandardError.new("Something went wrong") }

      before do
        allow(DocumentProcessing::TextChunker).to receive(:chunk).and_raise(unexpected_error)
      end

      it "marks document as failed with unexpected error message" do
        expect {
          described_class.new.perform(document.id)
        }.to raise_error(StandardError)

        document.reload
        expect(document.status).to eq("failed")
        expect(document.error_message).to include("An unexpected error occurred while processing the document")
        expect(document.error_message).to include("StandardError")
      end

      it "re-raises the original error" do
        expect {
          described_class.new.perform(document.id)
        }.to raise_error(StandardError, "Something went wrong")
      end
    end

    context "when document does not exist" do
      it "raises ActiveRecord::RecordNotFound" do
        expect {
          described_class.new.perform(99999)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "does not attempt to extract text" do
        expect {
          described_class.new.perform(99999)
        }.to raise_error(ActiveRecord::RecordNotFound)

        expect(DocumentProcessing::TextExtractor).not_to have_received(:extract)
      end
    end
  end

  describe "job queue" do
    it "is queued as default" do
      expect(described_class.new.queue_name).to eq("default")
    end
  end

  describe ProcessDocumentJob::ProcessingError do
    it "is a subclass of StandardError" do
      expect(described_class).to be < StandardError
    end

    it "can be instantiated with a message" do
      error = described_class.new("test error message")
      expect(error.message).to eq("test error message")
    end

    it "can be instantiated without a message" do
      error = described_class.new
      expect(error).to be_a(StandardError)
    end

    it "can be raised and rescued" do
      expect {
        raise described_class, "processing failed"
      }.to raise_error(described_class, "processing failed")
    end

    it "can be rescued as StandardError" do
      rescued = false
      begin
        raise described_class, "processing failed"
      rescue StandardError
        rescued = true
      end
      expect(rescued).to be true
    end
  end
end
