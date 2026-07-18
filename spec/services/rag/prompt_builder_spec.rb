require 'rails_helper'

RSpec.describe Rag::PromptBuilder do
  describe "#format_relevance" do
    let(:builder) { described_class.new }

    # Access the private method via send
    subject(:result) { builder.send(:format_relevance, distance) }

    describe "return type" do
      let(:distance) { 0.5 }

      it "returns a String" do
        expect(result).to be_a(String)
      end

      it "returns a non-empty string" do
        expect(result).not_to be_empty
      end
    end

    describe "output format" do
      let(:distance) { 0.5 }

      it "returns a string formatted to 2 decimal places" do
        expect(result).to match(/^\d+\.\d{2}$/)
      end

      it "does not return more than 2 decimal places" do
        expect(result).not_to match(/\.\d{3,}/)
      end

      it "returns a numeric string" do
        expect(result).to match(/^\d+\.\d+$/)
      end
    end

    describe "cosine distance to similarity conversion" do
      context "when distance is 0.0 (perfect match)" do
        let(:distance) { 0.0 }

        it "returns '1.00'" do
          expect(result).to eq("1.00")
        end

        it "returns the maximum similarity score" do
          expect(result.to_f).to eq(1.0)
        end
      end

      context "when distance is 1.0 (halfway)" do
        let(:distance) { 1.0 }

        it "returns '0.50'" do
          expect(result).to eq("0.50")
        end

        it "returns exactly 0.5 similarity" do
          expect(result.to_f).to eq(0.5)
        end
      end

      context "when distance is 2.0 (completely opposite)" do
        let(:distance) { 2.0 }

        it "returns '0.00'" do
          expect(result).to eq("0.00")
        end

        it "returns the minimum similarity score" do
          expect(result.to_f).to eq(0.0)
        end
      end

      context "when distance is 0.1" do
        let(:distance) { 0.1 }

        it "returns '0.95'" do
          expect(result).to eq("0.95")
        end
      end

      context "when distance is 0.2" do
        let(:distance) { 0.2 }

        it "returns '0.90'" do
          expect(result).to eq("0.90")
        end
      end

      context "when distance is 0.3" do
        let(:distance) { 0.3 }

        it "returns '0.85'" do
          expect(result).to eq("0.85")
        end
      end

      context "when distance is 0.5" do
        let(:distance) { 0.5 }

        it "returns '0.75'" do
          expect(result).to eq("0.75")
        end
      end

      context "when distance is 1.5" do
        let(:distance) { 1.5 }

        it "returns '0.25'" do
          expect(result).to eq("0.25")
        end
      end
    end

    describe "boundary conditions" do
      context "when distance is exactly 0.0" do
        let(:distance) { 0.0 }

        it "does not return a value greater than 1.00" do
          expect(result.to_f).to be <= 1.0
        end

        it "returns exactly '1.00'" do
          expect(result).to eq("1.00")
        end
      end

      context "when distance is exactly 2.0" do
        let(:distance) { 2.0 }

        it "does not return a value less than 0.00" do
          expect(result.to_f).to be >= 0.0
        end

        it "returns exactly '0.00'" do
          expect(result).to eq("0.00")
        end
      end

      context "when distance would produce a negative similarity (distance > 2.0)" do
        let(:distance) { 2.5 }

        it "does not return a negative value" do
          expect(result.to_f).to be >= 0.0
        end

        it "clamps the result to '0.00'" do
          expect(result).to eq("0.00")
        end

        it "does not raise an error" do
          expect { result }.not_to raise_error
        end
      end

      context "when distance is very large" do
        let(:distance) { 100.0 }

        it "returns '0.00' due to clamping" do
          expect(result).to eq("0.00")
        end

        it "does not return a negative value" do
          expect(result.to_f).to be >= 0.0
        end

        it "does not raise an error" do
          expect { result }.not_to raise_error
        end
      end
    end

    describe "formula: similarity = max(0, 1 - distance / 2.0)" do
      it "correctly converts distance 0.0 to similarity 1.00" do
        expect(builder.send(:format_relevance, 0.0)).to eq("1.00")
      end

      it "correctly converts distance 0.5 to similarity 0.75" do
        expect(builder.send(:format_relevance, 0.5)).to eq("0.75")
      end

      it "correctly converts distance 1.0 to similarity 0.50" do
        expect(builder.send(:format_relevance, 1.0)).to eq("0.50")
      end

      it "correctly converts distance 1.5 to similarity 0.25" do
        expect(builder.send(:format_relevance, 1.5)).to eq("0.25")
      end

      it "correctly converts distance 2.0 to similarity 0.00" do
        expect(builder.send(:format_relevance, 2.0)).to eq("0.00")
      end
    end

    describe "rounding behavior" do
      context "when the result has more than 2 decimal places" do
        let(:distance) { 1.0 / 3.0 }

        it "returns a string with exactly 2 decimal places" do
          expect(result).to match(/^\d+\.\d{2}$/)
        end

        it "does not raise an error" do
          expect { result }.not_to raise_error
        end
      end

      context "when distance results in a clean decimal" do
        let(:distance) { 0.4 }

        it "pads with zeros to ensure 2 decimal places" do
          expect(result).to match(/\.\d{2}$/)
        end
      end
    end

    describe "similarity score range" do
      [ 0.0, 0.1, 0.5, 1.0, 1.5, 2.0 ].each do |d|
        context "when distance is #{d}" do
          let(:distance) { d }

          it "returns a value between 0.00 and 1.00 inclusive" do
            expect(result.to_f).to be_between(0.0, 1.0).inclusive
          end
        end
      end
    end

    describe "integer distance values" do
      context "when distance is an integer 0" do
        let(:distance) { 0 }

        it "returns '1.00'" do
          expect(result).to eq("1.00")
        end

        it "does not raise an error" do
          expect { result }.not_to raise_error
        end
      end

      context "when distance is an integer 1" do
        let(:distance) { 1 }

        it "returns '0.50'" do
          expect(result).to eq("0.50")
        end

        it "does not raise an error" do
          expect { result }.not_to raise_error
        end
      end

      context "when distance is an integer 2" do
        let(:distance) { 2 }

        it "returns '0.00'" do
          expect(result).to eq("0.00")
        end

        it "does not raise an error" do
          expect { result }.not_to raise_error
        end
      end
    end

    describe "consistency with format_context" do
      let(:document) { build(:document, title: "Test Document") }
      let(:chunk) { build(:chunk, content: "Test content.", position: 0) }

      context "when distance is 0.1, format_context should display relevance: 0.95" do
        let(:chunks_data) do
          [ { chunk: chunk, document: document, content: chunk.content, distance: 0.1 } ]
        end

        it "produces the same relevance value as used in format_context" do
          format_relevance_result = builder.send(:format_relevance, 0.1)
          format_context_result = builder.send(:format_context, chunks_data)
          expect(format_context_result).to include("relevance: #{format_relevance_result}")
        end
      end

      context "when distance is 0.5, format_context should display relevance: 0.75" do
        let(:chunks_data) do
          [ { chunk: chunk, document: document, content: chunk.content, distance: 0.5 } ]
        end

        it "produces the same relevance value as used in format_context" do
          format_relevance_result = builder.send(:format_relevance, 0.5)
          format_context_result = builder.send(:format_context, chunks_data)
          expect(format_context_result).to include("relevance: #{format_relevance_result}")
        end
      end
    end
  end
end
