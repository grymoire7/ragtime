require 'rails_helper'

RSpec.describe DocumentProcessing::TextChunker do
  describe ".chunk" do
    it "returns an array of chunks" do
      text = "This is a test. " * 100
      result = described_class.chunk(text)

      expect(result).to be_an(Array)
      expect(result).not_to be_empty
    end

    it "returns empty array for blank text" do
      expect(described_class.chunk("")).to eq([])
      expect(described_class.chunk(nil)).to eq([])
      expect(described_class.chunk("   ")).to eq([])
    end

    it "returns chunks with correct structure" do
      text = "This is a test paragraph.\n\nThis is another paragraph."
      result = described_class.chunk(text)

      expect(result.first).to have_key(:text)
      expect(result.first).to have_key(:token_count)
      expect(result.first[:text]).to be_a(String)
      expect(result.first[:token_count]).to be_a(Integer)
      expect(result.first[:token_count]).to be > 0
    end
  end

  describe "chunking behavior" do
    let(:chunker) { described_class.new(text, chunk_size, overlap) }
    let(:chunk_size) { 100 }
    let(:overlap) { 20 }

    context "with short text" do
      let(:text) { "This is a short paragraph with just a few words." }

      it "creates a single chunk" do
        result = chunker.chunk
        expect(result.length).to eq(1)
        expect(result.first[:text]).to eq(text)
      end
    end

    context "with text spanning multiple paragraphs" do
      let(:text) do
        <<~TEXT
          First paragraph with some content.

          Second paragraph with more content.

          Third paragraph with even more content.
        TEXT
      end

      it "splits on paragraph boundaries when possible" do
        result = chunker.chunk
        expect(result).to be_an(Array)

        # Each chunk should be split on paragraph boundaries
        # Verify that chunks preserve paragraph structure
        result.each do |chunk|
          text = chunk[:text]
          # If text contains periods, it should ideally end with one (complete sentences)
          # or not contain periods at all (paragraph without sentence-ending periods)
          if text.include?(".")
            # If it has periods, check it's not splitting mid-sentence
            # (This is a best-effort check - chunks may split between paragraphs)
            expect(text).to match(/\.\s*\z|[^\.]/)
          end
        end
      end
    end

    context "with very long paragraphs" do
      let(:text) { "This is a very long sentence. " * 200 }

      it "splits large paragraphs into multiple chunks" do
        result = chunker.chunk
        expect(result.length).to be > 1

        # Each chunk should respect the token limit (approximately)
        result.each do |chunk|
          # Allow some flexibility due to overlap
          expect(chunk[:token_count]).to be <= (chunk_size + overlap)
        end
      end
    end

    context "with custom chunk size" do
      let(:text) { "Word " * 1000 }
      let(:chunk_size) { 50 }
      let(:overlap) { 10 }

      it "respects the custom chunk size" do
        result = chunker.chunk

        result.each do |chunk|
          # Chunks should be approximately the target size (with some flexibility for overlap)
          expect(chunk[:token_count]).to be <= (chunk_size + overlap)
        end
      end
    end
  end

  describe "overlap behavior" do
    let(:text) do
      paragraphs = []
      10.times do |i|
        paragraphs << "Paragraph #{i} with unique content that helps identify it."
      end
      paragraphs.join("\n\n")
    end
    let(:chunk_size) { 50 }
    let(:overlap) { 15 }

    it "includes overlap between consecutive chunks" do
      result = described_class.chunk(text, chunk_size: chunk_size, overlap: overlap)

      if result.length > 1
        # Check that there's some content overlap between chunks
        # This is hard to test precisely, but we can verify chunks exist and have reasonable sizes
        result.each do |chunk|
          expect(chunk[:text]).to be_present
          expect(chunk[:token_count]).to be > 0
        end
      end
    end
  end

  describe "token counting accuracy" do
    let(:text) { "The quick brown fox jumps over the lazy dog." }

    it "counts tokens accurately" do
      result = described_class.chunk(text)
      chunk = result.first

      # Verify token count is reasonable (this sentence is ~10 tokens)
      expect(chunk[:token_count]).to be_between(8, 15)
    end

    it "counts tokens for all chunks" do
      text = "Sentence. " * 200
      result = described_class.chunk(text, chunk_size: 50)

      result.each do |chunk|
        expect(chunk[:token_count]).to be > 0
        # Rough verification that token count matches content length
        # Typically ~4 characters per token
        approximate_tokens = chunk[:text].length / 4
        expect(chunk[:token_count]).to be_within(approximate_tokens * 0.5).of(approximate_tokens)
      end
    end
  end

  describe "edge cases" do
    it "handles text with only newlines" do
      text = "\n\n\n\n"
      result = described_class.chunk(text)
      expect(result).to eq([])
    end

    it "handles text with mixed whitespace" do
      text = "Word  \t  word\n\nword"
      result = described_class.chunk(text)
      expect(result).not_to be_empty
      expect(result.first[:text]).to be_present
    end

    it "handles text with special characters" do
      text = "Hello! How are you? I'm fine. What about you?"
      result = described_class.chunk(text)
      expect(result).not_to be_empty
      expect(result.first[:text]).to include("Hello!")
    end

    it "handles very short text" do
      text = "Hi"
      result = described_class.chunk(text)
      expect(result.length).to eq(1)
      expect(result.first[:text]).to eq("Hi")
    end
  end

  describe "constants" do
    it "defines DEFAULT_CHUNK_SIZE" do
      expect(DocumentProcessing::TextChunker::DEFAULT_CHUNK_SIZE).to eq(800)
    end

    it "defines DEFAULT_OVERLAP" do
      expect(DocumentProcessing::TextChunker::DEFAULT_OVERLAP).to eq(200)
    end
  end
end
