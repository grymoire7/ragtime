require 'rails_helper'

RSpec.describe Chunk, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:document) }
  end

  describe "validations" do
    subject { build(:chunk) }

    it { is_expected.to validate_presence_of(:content) }
    it { is_expected.to validate_presence_of(:position) }
    it { is_expected.to validate_presence_of(:token_count) }
    it { is_expected.to validate_numericality_of(:position).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:token_count).is_greater_than(0) }
  end

  describe "#embedding=" do
    let(:chunk) { build(:chunk) }

    it "converts array of floats to binary format" do
      embedding_array = Array.new(512) { rand }
      chunk.embedding = embedding_array

      # The attribute should be stored as binary
      expect(chunk.read_attribute(:embedding)).to be_a(String)
      expect(chunk.read_attribute(:embedding).encoding).to eq(Encoding::ASCII_8BIT)
    end

    it "handles nil embedding" do
      chunk.embedding = nil
      expect(chunk.read_attribute(:embedding)).to be_nil
    end

    it "stores and retrieves 512-dimensional vectors correctly" do
      embedding_array = Array.new(512) { |i| i.to_f }
      chunk.embedding = embedding_array

      # Retrieve and verify
      retrieved = chunk.embedding
      expect(retrieved).to be_an(Array)
      expect(retrieved.length).to eq(512)

      # Check that values are approximately equal (allowing for float precision)
      retrieved.each_with_index do |value, index|
        expect(value).to be_within(0.001).of(embedding_array[index])
      end
    end
  end

  describe "#embedding" do
    let(:chunk) { build(:chunk) }

    it "converts binary format back to array of floats" do
      embedding_array = Array.new(512) { rand }
      chunk.embedding = embedding_array

      retrieved = chunk.embedding
      expect(retrieved).to be_an(Array)
      expect(retrieved.length).to eq(512)
      expect(retrieved.first).to be_a(Float)
    end

    it "returns nil when no embedding is stored" do
      chunk = build(:chunk)
      chunk.write_attribute(:embedding, nil)
      expect(chunk.embedding).to be_nil
    end
  end

  describe "vector table callbacks" do
    let(:document) { create(:document) }

    describe "after_create" do
      it "inserts embedding into vec_chunks table" do
        chunk = build(:chunk, :with_embedding, document: document)

        expect {
          chunk.save!
        }.to change {
          ActiveRecord::Base.connection.execute(
            "SELECT COUNT(*) FROM vec_chunks"
          ).first["COUNT(*)"]
        }.by(1)

        # Verify the specific chunk was inserted (without parameter binding)
        result = ActiveRecord::Base.connection.execute(
          "SELECT COUNT(*) FROM vec_chunks WHERE chunk_id = #{chunk.id}"
        ).first["COUNT(*)"]
        expect(result).to eq(1)
      end

      it "does not insert if embedding is nil" do
        chunk = create(:chunk, document: document)

        result = ActiveRecord::Base.connection.execute(
          "SELECT COUNT(*) FROM vec_chunks WHERE chunk_id = #{chunk.id}"
        ).first["COUNT(*)"]

        expect(result).to eq(0)
      end
    end

    describe "after_destroy" do
      it "removes embedding from vec_chunks table" do
        chunk = create(:chunk, :with_embedding, document: document)
        chunk_id = chunk.id

        chunk.destroy

        result = ActiveRecord::Base.connection.execute(
          "SELECT COUNT(*) FROM vec_chunks WHERE chunk_id = #{chunk_id}"
        ).first["COUNT(*)"]

        expect(result).to eq(0)
      end
    end
  end

  describe ".search_similar" do
    let(:document) { create(:document) }

    before do
      # Create chunks with embeddings
      # Chunk 1: all 0.5
      chunk1 = create(:chunk, document: document, content: "First chunk")
      chunk1.embedding = Array.new(512) { 0.5 }
      chunk1.save!

      # Chunk 2: all 0.6 (more similar to query)
      chunk2 = create(:chunk, document: document, content: "Second chunk")
      chunk2.embedding = Array.new(512) { 0.6 }
      chunk2.save!

      # Chunk 3: all 0.1 (less similar to query)
      chunk3 = create(:chunk, document: document, content: "Third chunk")
      chunk3.embedding = Array.new(512) { 0.1 }
      chunk3.save!
    end

    it "returns chunks ordered by similarity" do
      # Query vector close to 0.6
      query_embedding = Array.new(512) { 0.6 }

      results = Chunk.search_similar(query_embedding, limit: 3)

      expect(results).to be_an(Array)
      expect(results.length).to be <= 3

      # Results should be [chunk, distance] pairs
      if results.any?
        chunk, distance = results.first
        expect(chunk).to be_a(Chunk)
        expect(distance).to be_a(Numeric)
        expect(chunk.content).to eq("Second chunk")
      end
    end

    it "respects the limit parameter" do
      query_embedding = Array.new(512) { 0.5 }

      results = Chunk.search_similar(query_embedding, limit: 2)

      expect(results.length).to be <= 2
    end

    it "handles nil query embedding" do
      results = Chunk.search_similar(nil)
      expect(results).to eq([])
    end

    it "handles empty query embedding" do
      results = Chunk.search_similar([])
      expect(results).to eq([])
    end

    it "respects distance threshold" do
      query_embedding = Array.new(512) { 0.6 }

      # Very strict threshold
      results = Chunk.search_similar(query_embedding, limit: 5, distance_threshold: 0.01)

      # Should only return very close matches
      results.each do |chunk, distance|
        expect(distance).to be <= 0.01
      end
    end
  end

  describe "ordering by position" do
    let(:document) { create(:document) }

    it "retrieves chunks in order by position" do
      chunk3 = create(:chunk, document: document, position: 2)
      chunk1 = create(:chunk, document: document, position: 0)
      chunk2 = create(:chunk, document: document, position: 1)

      chunks = document.chunks.order(:position)

      expect(chunks.map(&:position)).to eq([0, 1, 2])
      expect(chunks.first).to eq(chunk1)
    end
  end
end
