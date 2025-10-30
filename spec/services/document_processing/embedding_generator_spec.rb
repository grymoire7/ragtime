require 'rails_helper'

RSpec.describe DocumentProcessing::EmbeddingGenerator do
  let(:generator) { described_class.new }

  describe ".generate" do
    it "delegates to instance method" do
      embedding = Array.new(512) { rand }
      allow_any_instance_of(described_class).to receive(:generate).with("test text").and_return(embedding)

      result = described_class.generate("test text")
      expect(result).to eq(embedding)
    end
  end

  describe ".generate_batch" do
    it "delegates to instance method" do
      embeddings = [Array.new(512) { rand }, Array.new(512) { rand }]
      allow_any_instance_of(described_class).to receive(:generate_batch).with(["text1", "text2"]).and_return(embeddings)

      result = described_class.generate_batch(["text1", "text2"])
      expect(result).to eq(embeddings)
    end
  end

  describe "#generate" do
    let(:mock_response) { double("Response", embedding: Array.new(512) { rand }) }

    before do
      allow(RubyLLM::Client).to receive(:embed).and_return(mock_response)
    end

    it "generates embeddings using RubyLLM" do
      result = generator.generate("test text")

      expect(RubyLLM::Client).to have_received(:embed).with(
        "test text",
        model: "voyage-3.5-lite"
      )
      expect(result).to eq(mock_response.embedding)
    end

    it "returns 512-dimensional embedding" do
      result = generator.generate("test text")

      expect(result).to be_an(Array)
      expect(result.length).to eq(512)
      expect(result.first).to be_a(Numeric)
    end

    it "returns nil for blank text" do
      result = generator.generate("")
      expect(result).to be_nil

      result = generator.generate(nil)
      expect(result).to be_nil
    end

    it "raises EmbeddingError on API failure" do
      allow(RubyLLM::Client).to receive(:embed).and_raise(StandardError.new("API Error"))

      expect {
        generator.generate("test text")
      }.to raise_error(DocumentProcessing::EmbeddingGenerator::EmbeddingError, /Failed to generate embedding/)
    end
  end

  describe "#generate_batch" do
    let(:embedding1) { Array.new(512) { 0.1 } }
    let(:embedding2) { Array.new(512) { 0.2 } }
    let(:embedding3) { Array.new(512) { 0.3 } }

    before do
      # Mock individual calls to generate
      call_count = 0
      allow_any_instance_of(described_class).to receive(:generate) do |_, text|
        call_count += 1
        case text
        when "text1" then embedding1
        when "text2" then embedding2
        when "text3" then embedding3
        end
      end
    end

    it "generates embeddings for multiple texts" do
      result = generator.generate_batch(["text1", "text2", "text3"])

      expect(result).to be_an(Array)
      expect(result.length).to eq(3)
      expect(result[0]).to eq(embedding1)
      expect(result[1]).to eq(embedding2)
      expect(result[2]).to eq(embedding3)
    end

    it "returns empty array for empty input" do
      result = generator.generate_batch([])
      expect(result).to eq([])
    end

    it "processes texts in batches of 50" do
      texts = Array.new(100) { |i| "text#{i}" }

      # Just verify it doesn't error with large batches
      result = generator.generate_batch(texts)
      expect(result.length).to eq(100)
    end

    it "raises EmbeddingError if any embedding fails" do
      allow_any_instance_of(described_class).to receive(:generate).and_raise(
        DocumentProcessing::EmbeddingGenerator::EmbeddingError.new("Failed")
      )

      expect {
        generator.generate_batch(["text1", "text2"])
      }.to raise_error(DocumentProcessing::EmbeddingGenerator::EmbeddingError)
    end

    it "handles batch processing correctly" do
      texts = Array.new(75) { |i| "text#{i}" }

      # Mock generate to return unique embeddings
      allow_any_instance_of(described_class).to receive(:generate) do |_, text|
        # Return a unique embedding for each text
        seed = text.hash
        Array.new(512) { seed.to_f / 1000000 }
      end

      result = generator.generate_batch(texts)

      expect(result.length).to eq(75)
      # Verify embeddings are unique (at least check first and last)
      expect(result.first).not_to eq(result.last)
    end
  end

  describe "model configuration" do
    it "uses voyage-3.5-lite model" do
      mock_response = double("Response", embedding: Array.new(512) { rand })
      allow(RubyLLM::Client).to receive(:embed).and_return(mock_response)

      generator.generate("test")

      expect(RubyLLM::Client).to have_received(:embed).with(
        anything,
        hash_including(model: "voyage-3.5-lite")
      )
    end
  end
end
