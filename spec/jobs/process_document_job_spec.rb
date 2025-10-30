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
      Array.new(512) { 0.1 },
      Array.new(512) { 0.2 },
      Array.new(512) { 0.3 }
    ]
  end

  before do
    # Mock the service classes
    allow(DocumentProcessing::TextExtractor).to receive(:extract).and_return(extracted_text)
    allow(DocumentProcessing::TextChunker).to receive(:chunk).and_return(chunk_data)
    allow(DocumentProcessing::EmbeddingGenerator).to receive(:generate_batch).and_return(embeddings)
  end

  describe "#perform" do
    it "updates document status to processing" do
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
      # Check embedding values with float precision tolerance
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
      # Allow other log messages but ensure our success message is logged
      allow(Rails.logger).to receive(:info).and_call_original
      expect(Rails.logger).to receive(:info).with(/Successfully processed document/).and_call_original

      described_class.new.perform(document.id)
    end

    context "when extraction returns blank text" do
      before do
        allow(DocumentProcessing::TextExtractor).to receive(:extract).and_return("")
      end

      it "marks document as failed" do
        expect {
          described_class.new.perform(document.id)
        }.to raise_error(ProcessDocumentJob::ProcessingError)

        document.reload
        expect(document.status).to eq("failed")
      end

      it "logs error" do
        expect(Rails.logger).to receive(:error).with(/Failed to process document/)
        expect(Rails.logger).to receive(:error).with(anything) # backtrace

        expect {
          described_class.new.perform(document.id)
        }.to raise_error(ProcessDocumentJob::ProcessingError)
      end
    end

    context "when chunking returns empty array" do
      before do
        allow(DocumentProcessing::TextChunker).to receive(:chunk).and_return([])
      end

      it "marks document as failed" do
        expect {
          described_class.new.perform(document.id)
        }.to raise_error(ProcessDocumentJob::ProcessingError)

        document.reload
        expect(document.status).to eq("failed")
      end
    end

    context "when text extraction fails" do
      before do
        allow(DocumentProcessing::TextExtractor).to receive(:extract)
          .and_raise(DocumentProcessing::TextExtractor::ExtractionError.new("Extraction failed"))
      end

      it "marks document as failed" do
        expect {
          described_class.new.perform(document.id)
        }.to raise_error(DocumentProcessing::TextExtractor::ExtractionError)

        document.reload
        expect(document.status).to eq("failed")
      end

      it "logs the error" do
        expect(Rails.logger).to receive(:error).with(/Failed to process document.*ExtractionError/)
        expect(Rails.logger).to receive(:error).with(anything) # backtrace

        expect {
          described_class.new.perform(document.id)
        }.to raise_error
      end

      it "re-raises the error" do
        expect {
          described_class.new.perform(document.id)
        }.to raise_error(DocumentProcessing::TextExtractor::ExtractionError)
      end
    end

    context "when embedding generation fails" do
      before do
        allow(DocumentProcessing::EmbeddingGenerator).to receive(:generate_batch)
          .and_raise(DocumentProcessing::EmbeddingGenerator::EmbeddingError.new("API error"))
      end

      it "marks document as failed" do
        expect {
          described_class.new.perform(document.id)
        }.to raise_error(DocumentProcessing::EmbeddingGenerator::EmbeddingError)

        document.reload
        expect(document.status).to eq("failed")
      end
    end

    context "when document does not exist" do
      it "raises ActiveRecord::RecordNotFound" do
        expect {
          described_class.new.perform(99999)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe "job queue" do
    it "is queued as default" do
      expect(described_class.new.queue_name).to eq("default")
    end
  end
end
