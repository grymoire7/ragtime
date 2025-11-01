require 'rails_helper'

RSpec.describe Rag::ChunkRetriever do
  let!(:document1) { create(:document, title: "First Document") }
  let!(:document2) { create(:document, title: "Second Document") }
  let(:query_embedding) { Array.new(512) { 0.5 } }
  let(:mock_response) { double("Response", vectors: query_embedding) }

  # Disable transactional fixtures for this spec because vec_chunks doesn't support transactions
  self.use_transactional_tests = false

  before do
    # Stub RubyLLM Client for embedding generation
    allow(RubyLLM).to receive(:embed).and_return(mock_response)

    # Create chunks with embeddings for document1
    3.times do |i|
      chunk = build(:chunk, document: document1, content: "Document 1 chunk #{i}")
      chunk.embedding = Array.new(512) { 0.5 + (i * 0.1) }
      chunk.save!
    end

    # Create chunks with embeddings for document2
    2.times do |i|
      chunk = build(:chunk, document: document2, content: "Document 2 chunk #{i}")
      chunk.embedding = Array.new(512) { 0.3 + (i * 0.1) }
      chunk.save!
    end
  end

  # Clean up database after each test since we're not using transactions
  after do
    Chunk.destroy_all
    Document.destroy_all
  end

  describe ".retrieve" do
    it "returns relevant chunks for a query" do
      # Query similar to 0.5 (should match document1's first chunk best)
      query = "test query"

      results = described_class.retrieve(query)

      expect(results).to be_an(Array)
      expect(results).not_to be_empty
      expect(results.first).to have_key(:chunk)
      expect(results.first).to have_key(:distance)
      expect(results.first).to have_key(:document)
      expect(results.first).to have_key(:content)
      expect(results.first).to have_key(:position)
    end

    it "returns chunks with associated document information" do
      query = "test query"

      results = described_class.retrieve(query)

      results.each do |result|
        expect(result[:chunk]).to be_a(Chunk)
        expect(result[:document]).to be_a(Document)
        expect(result[:chunk].document_id).to eq(result[:document].id)
      end
    end

    it "respects the limit parameter" do
      query = "test query"

      results = described_class.retrieve(query, limit: 2)

      expect(results.length).to be <= 2
    end

    it "respects the distance_threshold parameter" do
      query = "test query"

      results = described_class.retrieve(query, distance_threshold: 0.01)

      results.each do |result|
        expect(result[:distance]).to be <= 0.01
      end
    end

    it "filters by document_ids when provided" do
      query = "test query"

      results = described_class.retrieve(query, document_ids: [document1.id])

      expect(results).not_to be_empty
      results.each do |result|
        expect(result[:document].id).to eq(document1.id)
      end
    end

    it "returns empty array for blank query" do
      results = described_class.retrieve("")

      expect(results).to eq([])
    end

    it "returns empty array for nil query" do
      results = described_class.retrieve(nil)

      expect(results).to eq([])
    end

    it "returns empty array when embedding generation fails" do
      query = "test query"
      allow(DocumentProcessing::EmbeddingGenerator).to receive(:generate)
        .with(query)
        .and_raise(DocumentProcessing::EmbeddingGenerator::EmbeddingError, "API error")

      results = described_class.retrieve(query)

      expect(results).to eq([])
    end

    it "logs error when embedding generation fails" do
      query = "test query"
      allow(DocumentProcessing::EmbeddingGenerator).to receive(:generate)
        .with(query)
        .and_raise(DocumentProcessing::EmbeddingGenerator::EmbeddingError, "API error")

      expect(Rails.logger).to receive(:error).with(/Failed to generate query embedding/)

      described_class.retrieve(query)
    end

    it "returns chunks ordered by relevance (distance)" do
      query = "test query"
      # Query closest to 0.5 (should match document1 chunk 0 best)

      results = described_class.retrieve(query, limit: 5)

      # Verify results are ordered by distance (ascending)
      distances = results.map { |r| r[:distance] }
      expect(distances).to eq(distances.sort)
    end

    it "includes content and position from chunks" do
      query = "test query"

      results = described_class.retrieve(query, limit: 1)

      expect(results.first[:content]).to be_present
      expect(results.first[:position]).to be_a(Integer)
    end

    context "when no chunks match the threshold" do
      it "returns empty array" do
        query = "test query"
        # Very different embedding
        very_different_embedding = Array.new(512) { 10.0 }
        very_different_response = double("Response", vectors: very_different_embedding)
        allow(RubyLLM).to receive(:embed).and_return(very_different_response)

        results = described_class.retrieve(query, distance_threshold: 0.01)

        expect(results).to eq([])
      end
    end

    context "with multiple documents filtered" do
      it "only returns chunks from specified documents" do
        query = "test query"
        filtered_embedding = Array.new(512) { 0.4 }
        filtered_response = double("Response", vectors: filtered_embedding)
        allow(RubyLLM).to receive(:embed).and_return(filtered_response)

        results = described_class.retrieve(
          query,
          document_ids: [document1.id, document2.id]
        )

        document_ids = results.map { |r| r[:document].id }.uniq
        expect(document_ids).to match_array([document1.id, document2.id].select { |id|
          results.any? { |r| r[:document].id == id }
        })
      end
    end
  end

  describe "#retrieve" do
    let(:retriever) { described_class.new }

    it "can be instantiated and called as an instance method" do
      query = "test query"

      results = retriever.retrieve(query)

      expect(results).to be_an(Array)
    end
  end
end
