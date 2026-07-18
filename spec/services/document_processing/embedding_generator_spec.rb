require 'rails_helper'

RSpec.describe DocumentProcessing::EmbeddingGenerator do
  describe "#pad_embedding" do
    subject(:instance) { described_class.new }

    # Access private method for testing
    let(:pad_embedding) { ->(embedding) { instance.send(:pad_embedding, embedding) } }

    context "when embedding has exactly TARGET_DIMENSION (1536) dimensions" do
      let(:embedding) { Array.new(1536) { rand } }

      it "returns the embedding unchanged" do
        result = pad_embedding.call(embedding)
        expect(result).to eq(embedding)
      end

      it "returns an array with exactly 1536 elements" do
        result = pad_embedding.call(embedding)
        expect(result.length).to eq(1536)
      end

      it "returns the same object (no unnecessary copying)" do
        result = pad_embedding.call(embedding)
        expect(result).to equal(embedding)
      end

      it "does not modify the original embedding" do
        original = embedding.dup
        pad_embedding.call(embedding)
        expect(embedding).to eq(original)
      end
    end

    context "when embedding has fewer than TARGET_DIMENSION dimensions" do
      context "with 512-dimensional embedding (Ollama jina-embeddings)" do
        let(:embedding) { Array.new(512) { rand } }

        it "returns an array with exactly 1536 elements" do
          result = pad_embedding.call(embedding)
          expect(result.length).to eq(1536)
        end

        it "preserves the original embedding values at the start" do
          result = pad_embedding.call(embedding)
          expect(result.first(512)).to eq(embedding)
        end

        it "pads the remaining elements with zeros" do
          result = pad_embedding.call(embedding)
          expect(result.last(1536 - 512)).to all(eq(0.0))
        end

        it "pads with exactly 1024 zeros" do
          result = pad_embedding.call(embedding)
          zero_count = result.count { |v| v == 0.0 }
          expect(zero_count).to eq(1024)
        end

        it "returns an Array" do
          result = pad_embedding.call(embedding)
          expect(result).to be_an(Array)
        end

        it "returns an array of floats" do
          result = pad_embedding.call(embedding)
          expect(result).to all(be_a(Numeric))
        end
      end

      context "with 1-dimensional embedding" do
        let(:embedding) { [ 0.5 ] }

        it "returns an array with exactly 1536 elements" do
          result = pad_embedding.call(embedding)
          expect(result.length).to eq(1536)
        end

        it "preserves the original value at index 0" do
          result = pad_embedding.call(embedding)
          expect(result.first).to eq(0.5)
        end

        it "pads the remaining 1535 elements with zeros" do
          result = pad_embedding.call(embedding)
          expect(result.last(1535)).to all(eq(0.0))
        end
      end

      context "with 1535-dimensional embedding (one short)" do
        let(:embedding) { Array.new(1535) { rand } }

        it "returns an array with exactly 1536 elements" do
          result = pad_embedding.call(embedding)
          expect(result.length).to eq(1536)
        end

        it "preserves all original values" do
          result = pad_embedding.call(embedding)
          expect(result.first(1535)).to eq(embedding)
        end

        it "pads with exactly one zero at the end" do
          result = pad_embedding.call(embedding)
          expect(result.last).to eq(0.0)
        end
      end

      context "with an empty embedding" do
        let(:embedding) { [] }

        it "returns an array with exactly 1536 elements" do
          result = pad_embedding.call(embedding)
          expect(result.length).to eq(1536)
        end

        it "fills entirely with zeros" do
          result = pad_embedding.call(embedding)
          expect(result).to all(eq(0.0))
        end
      end

      context "with embeddings containing specific float values" do
        let(:embedding) { [ 1.0, 2.5, -3.7, 0.0, 0.123456789 ] }

        it "preserves the exact float values" do
          result = pad_embedding.call(embedding)
          expect(result[0]).to eq(1.0)
          expect(result[1]).to eq(2.5)
          expect(result[2]).to eq(-3.7)
          expect(result[3]).to eq(0.0)
          expect(result[4]).to eq(0.123456789)
        end

        it "pads with 0.0 not just 0" do
          result = pad_embedding.call(embedding)
          padded_section = result.last(1536 - embedding.length)
          padded_section.each do |val|
            expect(val).to be_a(Float)
            expect(val).to eq(0.0)
          end
        end

        it "returns an array of 1536 elements" do
          result = pad_embedding.call(embedding)
          expect(result.length).to eq(1536)
        end
      end

      context "with embeddings containing negative values" do
        let(:embedding) { Array.new(256) { -rand } }

        it "preserves negative values" do
          result = pad_embedding.call(embedding)
          expect(result.first(256)).to eq(embedding)
        end

        it "pads with positive zeros, not negative zeros" do
          result = pad_embedding.call(embedding)
          expect(result.last(1536 - 256)).to all(eq(0.0))
        end
      end
    end

    context "when embedding has more than TARGET_DIMENSION dimensions" do
      context "with 2048-dimensional embedding" do
        let(:embedding) { Array.new(2048) { rand } }

        it "returns an array with exactly 1536 elements" do
          result = pad_embedding.call(embedding)
          expect(result.length).to eq(1536)
        end

        it "returns the first 1536 elements" do
          result = pad_embedding.call(embedding)
          expect(result).to eq(embedding.first(1536))
        end

        it "drops the excess elements" do
          result = pad_embedding.call(embedding)
          expect(result).not_to include(*embedding.last(512))
        end

        it "returns an Array" do
          result = pad_embedding.call(embedding)
          expect(result).to be_an(Array)
        end
      end

      context "with 1537-dimensional embedding (one over)" do
        let(:embedding) { Array.new(1537) { rand } }

        it "returns an array with exactly 1536 elements" do
          result = pad_embedding.call(embedding)
          expect(result.length).to eq(1536)
        end

        it "returns the first 1536 elements" do
          result = pad_embedding.call(embedding)
          expect(result).to eq(embedding.first(1536))
        end

        it "excludes the last element" do
          result = pad_embedding.call(embedding)
          expect(result).not_to include(embedding.last)
        end
      end

      context "with a very large embedding" do
        let(:embedding) { Array.new(4096) { rand } }

        it "truncates to exactly 1536 elements" do
          result = pad_embedding.call(embedding)
          expect(result.length).to eq(1536)
        end

        it "preserves the first 1536 values exactly" do
          result = pad_embedding.call(embedding)
          expect(result).to eq(embedding.take(1536))
        end
      end
    end

    context "when verifying TARGET_DIMENSION constant" do
      it "TARGET_DIMENSION is 1536" do
        expect(described_class::TARGET_DIMENSION).to eq(1536)
      end

      it "pads to match TARGET_DIMENSION" do
        short_embedding = Array.new(100) { rand }
        result = pad_embedding.call(short_embedding)
        expect(result.length).to eq(described_class::TARGET_DIMENSION)
      end

      it "truncates to match TARGET_DIMENSION" do
        long_embedding = Array.new(2000) { rand }
        result = pad_embedding.call(long_embedding)
        expect(result.length).to eq(described_class::TARGET_DIMENSION)
      end
    end

    context "when verifying return type and structure" do
      let(:embedding) { Array.new(512) { rand } }

      it "always returns an Array" do
        result = pad_embedding.call(embedding)
        expect(result).to be_a(Array)
      end

      it "does not return nil" do
        result = pad_embedding.call(embedding)
        expect(result).not_to be_nil
      end

      it "returns an array without nil elements" do
        result = pad_embedding.call(embedding)
        expect(result).not_to include(nil)
      end

      it "returns numeric values only" do
        result = pad_embedding.call(embedding)
        expect(result).to all(be_a(Numeric))
      end
    end

    context "when called with embeddings of various sizes around the boundary" do
      [ 511, 512, 513, 1535, 1536, 1537 ].each do |size|
        context "with #{size}-dimensional embedding" do
          let(:embedding) { Array.new(size) { rand } }

          it "always returns exactly 1536 dimensions" do
            result = pad_embedding.call(embedding)
            expect(result.length).to eq(1536)
          end
        end
      end
    end

    context "when embedding contains zero values mixed with non-zero values" do
      let(:embedding) { [ 0.0, 1.0, 0.0, 2.0 ] }

      it "preserves existing zeros in original embedding" do
        result = pad_embedding.call(embedding)
        expect(result[0]).to eq(0.0)
        expect(result[2]).to eq(0.0)
      end

      it "pads remaining positions with zeros" do
        result = pad_embedding.call(embedding)
        expect(result.last(1536 - 4)).to all(eq(0.0))
      end

      it "correctly pads to 1536 dimensions" do
        result = pad_embedding.call(embedding)
        expect(result.length).to eq(1536)
      end
    end
  end
end
