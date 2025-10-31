require 'rails_helper'

RSpec.describe Rag::PromptBuilder do
  describe ".build" do
    let(:question) { "What is the capital of France?" }

    context "with no context chunks" do
      it "returns a no-context prompt" do
        result = described_class.build(question, [])

        expect(result).to include("no relevant documents were found")
        expect(result).to include(question)
      end
    end

    context "with context chunks" do
      let(:document1) { build(:document, title: "Geography Facts") }
      let(:document2) { build(:document, title: "European Cities") }

      let(:chunk1) { build(:chunk, content: "Paris is the capital of France.", position: 0) }
      let(:chunk2) { build(:chunk, content: "France is a country in Europe.", position: 1) }

      let(:chunks_data) do
        [
          {
            chunk: chunk1,
            document: document1,
            content: chunk1.content,
            distance: 0.1
          },
          {
            chunk: chunk2,
            document: document2,
            content: chunk2.content,
            distance: 0.3
          }
        ]
      end

      it "includes the question" do
        result = described_class.build(question, chunks_data)

        expect(result).to include(question)
      end

      it "includes all chunk contents" do
        result = described_class.build(question, chunks_data)

        expect(result).to include(chunk1.content)
        expect(result).to include(chunk2.content)
      end

      it "includes document titles" do
        result = described_class.build(question, chunks_data)

        expect(result).to include("Geography Facts")
        expect(result).to include("European Cities")
      end

      it "includes relevance scores" do
        result = described_class.build(question, chunks_data)

        expect(result).to include("relevance:")
      end

      it "numbers the chunks" do
        result = described_class.build(question, chunks_data)

        expect(result).to include("[1]")
        expect(result).to include("[2]")
      end

      it "includes instructions to answer based on context" do
        result = described_class.build(question, chunks_data)

        expect(result).to include("based ONLY on the context")
        expect(result).to include("Cite which documents")
      end

      it "separates chunks with dividers" do
        result = described_class.build(question, chunks_data)

        expect(result).to include("---")
      end
    end

    context "with chunks missing document information" do
      let(:chunk) { build(:chunk, content: "Some content", position: 0) }
      let(:chunks_data) do
        [
          {
            chunk: chunk,
            document: nil,
            content: chunk.content,
            distance: 0.2
          }
        ]
      end

      it "handles missing document gracefully" do
        result = described_class.build(question, chunks_data)

        expect(result).to include("Unknown Document")
        expect(result).to include(chunk.content)
      end
    end

    context "with chunks missing distance information" do
      let(:document) { build(:document, title: "Test Doc") }
      let(:chunk) { build(:chunk, content: "Some content", position: 0) }
      let(:chunks_data) do
        [
          {
            chunk: chunk,
            document: document,
            content: chunk.content,
            distance: nil
          }
        ]
      end

      it "handles missing distance gracefully" do
        result = described_class.build(question, chunks_data)

        expect(result).to include(chunk.content)
        expect(result).to include("Test Doc")
        # Should not crash, may or may not include relevance
      end
    end
  end

  describe "#build" do
    let(:builder) { described_class.new }
    let(:question) { "Test question?" }

    it "can be instantiated and called as an instance method" do
      result = builder.build(question, [])

      expect(result).to be_a(String)
      expect(result).to include(question)
    end
  end

  describe "relevance formatting" do
    let(:document) { build(:document, title: "Test") }
    let(:chunk) { build(:chunk, content: "Content", position: 0) }
    let(:question) { "Question?" }

    it "formats perfect match (distance 0) as 1.00" do
      chunks_data = [{
        chunk: chunk,
        document: document,
        content: chunk.content,
        distance: 0.0
      }]

      result = described_class.build(question, chunks_data)

      expect(result).to include("relevance: 1.00")
    end

    it "formats medium distance (0.5) correctly" do
      chunks_data = [{
        chunk: chunk,
        document: document,
        content: chunk.content,
        distance: 0.5
      }]

      result = described_class.build(question, chunks_data)

      expect(result).to match(/relevance: 0\.(7[0-9]|[89][0-9])/)
    end
  end
end
