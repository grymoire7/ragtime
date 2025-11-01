require 'rails_helper'

RSpec.describe Rag::AnswerGenerator do
  let(:question) { "What is the capital of France?" }
  let(:mock_llm_response) { double("Response", content: "Paris is the capital of France.") }
  let(:mock_chat) { double("Chat", ask: mock_llm_response) }

  before do
    # Stub RubyLLM Client
    allow(RubyLLM).to receive(:chat).and_return(mock_chat)
  end

  describe ".generate" do
    context "when chunks are found" do
      let(:document) { build(:document, id: 1, title: "Geography Facts") }
      let(:chunk) { build(:chunk, id: 1, content: "Paris is the capital of France.", position: 0) }

      let(:chunks_data) do
        [
          {
            chunk: chunk,
            document: document,
            content: chunk.content,
            distance: 0.1
          }
        ]
      end

      before do
        allow(Rag::ChunkRetriever).to receive(:retrieve).and_return(chunks_data)
        allow(Rag::PromptBuilder).to receive(:build).and_return("Mock prompt")
      end

      it "returns a hash with answer" do
        result = described_class.generate(question)

        expect(result).to be_a(Hash)
        expect(result[:answer]).to eq("Paris is the capital of France.")
      end

      it "includes chunks used in response" do
        result = described_class.generate(question)

        expect(result[:chunks_used]).to be_an(Array)
        expect(result[:chunks_used].first).to include(id: 1, document_title: "Geography Facts")
      end

      it "includes model used" do
        result = described_class.generate(question)

        # Uses test environment model from config
        expect(result[:model]).to eq("test-chat-model")
      end

      it "calls ChunkRetriever with correct parameters" do
        expect(Rag::ChunkRetriever).to receive(:retrieve).with(
          question,
          limit: 5,
          distance_threshold: 1.0,
          document_ids: nil
        )

        described_class.generate(question)
      end

      it "calls PromptBuilder with chunks" do
        expect(Rag::PromptBuilder).to receive(:build).with(question, chunks_data)

        described_class.generate(question)
      end

      it "calls LLM with the built prompt" do
        expect(RubyLLM).to receive(:chat).with(
          model: "test-chat-model",
          provider: :test
        ).and_return(mock_chat)

        expect(mock_chat).to receive(:ask).with("Mock prompt")

        described_class.generate(question)
      end
    end

    context "with custom options" do
      let(:chunks_data) { [] }

      before do
        allow(Rag::ChunkRetriever).to receive(:retrieve).and_return(chunks_data)
        allow(Rag::PromptBuilder).to receive(:build).and_return("Mock prompt")
      end

      it "respects custom limit" do
        expect(Rag::ChunkRetriever).to receive(:retrieve).with(
          question,
          hash_including(limit: 10)
        )

        described_class.generate(question, limit: 10)
      end

      it "respects custom distance_threshold" do
        expect(Rag::ChunkRetriever).to receive(:retrieve).with(
          question,
          hash_including(distance_threshold: 0.5)
        )

        described_class.generate(question, distance_threshold: 0.5)
      end

      it "respects custom document_ids" do
        expect(Rag::ChunkRetriever).to receive(:retrieve).with(
          question,
          hash_including(document_ids: [1, 2, 3])
        )

        described_class.generate(question, document_ids: [1, 2, 3])
      end

      it "respects custom model" do
        expect(RubyLLM).to receive(:chat).with(
          hash_including(model: "claude-3-opus-latest")
        ).and_return(mock_chat)

        described_class.generate(question, model: "claude-3-opus-latest")
      end
    end

    context "when no chunks are found" do
      before do
        allow(Rag::ChunkRetriever).to receive(:retrieve).and_return([])
        allow(Rag::PromptBuilder).to receive(:build).and_return("No context prompt")
      end

      it "still generates an answer" do
        result = described_class.generate(question)

        expect(result[:answer]).to be_present
      end

      it "has empty chunks_used" do
        result = described_class.generate(question)

        expect(result[:chunks_used]).to eq([])
      end

      it "calls PromptBuilder with empty chunks" do
        expect(Rag::PromptBuilder).to receive(:build).with(question, [])

        described_class.generate(question)
      end
    end

    context "when LLM call fails" do
      before do
        allow(Rag::ChunkRetriever).to receive(:retrieve).and_return([])
        allow(Rag::PromptBuilder).to receive(:build).and_return("Mock prompt")
        allow(RubyLLM).to receive(:chat).and_raise(StandardError.new("API Error"))
      end

      it "returns error response" do
        result = described_class.generate(question)

        expect(result[:answer]).to include("error")
        expect(result[:error]).to be_present
      end

      it "logs the error" do
        expect(Rails.logger).to receive(:error).at_least(:once)

        described_class.generate(question)
      end

      it "includes error message" do
        result = described_class.generate(question)

        expect(result[:error]).to include("API Error")
      end
    end

    context "when retrieval fails" do
      before do
        allow(Rag::ChunkRetriever).to receive(:retrieve).and_raise(StandardError.new("Retrieval failed"))
      end

      it "returns error response" do
        result = described_class.generate(question)

        expect(result[:answer]).to include("error")
        expect(result[:error]).to be_present
      end

      it "logs the error" do
        expect(Rails.logger).to receive(:error).at_least(:once)

        described_class.generate(question)
      end
    end
  end

  describe "#generate" do
    let(:generator) { described_class.new }
    let(:chunks_data) { [] }

    before do
      allow(Rag::ChunkRetriever).to receive(:retrieve).and_return(chunks_data)
      allow(Rag::PromptBuilder).to receive(:build).and_return("Mock prompt")
    end

    it "can be instantiated and called as an instance method" do
      result = generator.generate(question)

      expect(result).to be_a(Hash)
      expect(result[:answer]).to be_present
    end
  end

  describe "chunks_used formatting" do
    let(:document1) { build(:document, id: 1, title: "Doc 1") }
    let(:document2) { build(:document, id: 2, title: "Doc 2") }
    let(:chunk1) { build(:chunk, id: 10, content: "Content 1", position: 0) }
    let(:chunk2) { build(:chunk, id: 20, content: "Content 2", position: 1) }

    let(:chunks_data) do
      [
        { chunk: chunk1, document: document1, content: chunk1.content, distance: 0.1 },
        { chunk: chunk2, document: document2, content: chunk2.content, distance: 0.2 }
      ]
    end

    before do
      allow(Rag::ChunkRetriever).to receive(:retrieve).and_return(chunks_data)
      allow(Rag::PromptBuilder).to receive(:build).and_return("Mock prompt")
    end

    it "includes all chunks with their document titles" do
      result = described_class.generate(question)

      expect(result[:chunks_used].length).to eq(2)
      expect(result[:chunks_used][0]).to eq(id: 10, document_title: "Doc 1")
      expect(result[:chunks_used][1]).to eq(id: 20, document_title: "Doc 2")
    end
  end

  describe "chunks_used with nil document" do
    let(:chunk) { build(:chunk, id: 1, content: "Content", position: 0) }
    let(:chunks_data) do
      [
        { chunk: chunk, document: nil, content: chunk.content, distance: 0.1 }
      ]
    end

    before do
      allow(Rag::ChunkRetriever).to receive(:retrieve).and_return(chunks_data)
      allow(Rag::PromptBuilder).to receive(:build).and_return("Mock prompt")
    end

    it "handles nil document gracefully" do
      result = described_class.generate(question)

      expect(result[:chunks_used].first).to eq(id: 1, document_title: nil)
    end
  end
end
