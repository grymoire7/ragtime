require 'rails_helper'

RSpec.describe Document, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:chunks).dependent(:destroy) }
    it { is_expected.to have_one_attached(:file) }

    describe "chunks ordering" do
      it "returns chunks ordered by position ascending" do
        document = create(:document)
        chunk_2 = create(:chunk, document: document, position: 2, content: "Third chunk")
        chunk_0 = create(:chunk, document: document, position: 0, content: "First chunk")
        chunk_1 = create(:chunk, document: document, position: 1, content: "Second chunk")

        # Reload to get fresh association query
        document.reload

        expect(document.chunks.to_a).to eq([chunk_0, chunk_1, chunk_2])
        expect(document.chunks.map(&:position)).to eq([0, 1, 2])
      end

      it "maintains order when chunks are created out of sequence" do
        document = create(:document)

        # Create chunks in reverse order
        (4).downto(0).each do |i|
          create(:chunk, document: document, position: i, content: "Chunk #{i}")
        end

        document.reload

        expect(document.chunks.map(&:position)).to eq([0, 1, 2, 3, 4])
      end

      it "returns chunks in position order even after new chunks are added" do
        document = create(:document)
        chunk_0 = create(:chunk, document: document, position: 0)
        chunk_2 = create(:chunk, document: document, position: 2)

        # Add chunk in the middle
        chunk_1 = create(:chunk, document: document, position: 1)

        document.reload

        expect(document.chunks.to_a).to eq([chunk_0, chunk_1, chunk_2])
      end
    end
  end

  describe "validations" do
    subject { build(:document) }

    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:filename) }
    it { is_expected.to validate_presence_of(:content_type) }
    it { is_expected.to validate_presence_of(:file_size) }
    it { is_expected.to validate_numericality_of(:file_size).is_greater_than(0) }
  end

  describe "enums" do
    it "defines status enum with correct values" do
      expect(Document.statuses).to eq({
        "pending" => "pending",
        "processing" => "processing",
        "completed" => "completed",
        "failed" => "failed"
      })
    end

    it "defaults to pending status" do
      document = Document.new
      expect(document.status).to eq("pending")
    end
  end

  describe "#supported_format?" do
    it "returns true for PDF" do
      document = build(:document, content_type: "application/pdf")
      expect(document.supported_format?).to be true
    end

    it "returns true for plain text" do
      document = build(:document, content_type: "text/plain")
      expect(document.supported_format?).to be true
    end

    it "returns true for DOCX" do
      document = build(:document, content_type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document")
      expect(document.supported_format?).to be true
    end

    it "returns true for markdown" do
      document = build(:document, content_type: "text/markdown")
      expect(document.supported_format?).to be true
    end

    it "returns false for unsupported formats" do
      document = build(:document, content_type: "image/png")
      expect(document.supported_format?).to be false
    end
  end

  describe "#pdf?" do
    it "returns true for PDF documents" do
      document = build(:document, content_type: "application/pdf")
      expect(document.pdf?).to be true
    end

    it "returns false for non-PDF documents" do
      document = build(:document, content_type: "text/plain")
      expect(document.pdf?).to be false
    end
  end

  describe "#text?" do
    it "returns true for text documents" do
      document = build(:document, content_type: "text/plain")
      expect(document.text?).to be true
    end

    it "returns false for non-text documents" do
      document = build(:document, content_type: "application/pdf")
      expect(document.text?).to be false
    end
  end

  describe "#docx?" do
    it "returns true for DOCX documents" do
      document = build(:document, content_type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document")
      expect(document.docx?).to be true
    end

    it "returns false for non-DOCX documents" do
      document = build(:document, content_type: "application/pdf")
      expect(document.docx?).to be false
    end
  end

  describe "#markdown?" do
    it "returns true for markdown documents" do
      document = build(:document, content_type: "text/markdown")
      expect(document.markdown?).to be true
    end

    it "returns false for non-markdown documents" do
      document = build(:document, content_type: "application/pdf")
      expect(document.markdown?).to be false
    end
  end

  describe "status transitions" do
    let(:document) { create(:document) }

    it "can transition from pending to processing" do
      expect { document.update!(status: :processing) }.not_to raise_error
      expect(document.status).to eq("processing")
    end

    it "can transition from processing to completed" do
      document.update!(status: :processing)
      expect { document.update!(status: :completed) }.not_to raise_error
      expect(document.status).to eq("completed")
    end

    it "can transition from processing to failed" do
      document.update!(status: :processing)
      expect { document.update!(status: :failed) }.not_to raise_error
      expect(document.status).to eq("failed")
    end
  end

  describe "dependent destroy" do
    it "destroys associated chunks when document is destroyed" do
      document = create(:document, :with_chunks)
      chunk_ids = document.chunks.pluck(:id)

      document.destroy

      chunk_ids.each do |chunk_id|
        expect(Chunk.exists?(chunk_id)).to be false
      end
    end
  end

  describe "SUPPORTED_CONTENT_TYPES" do
    it "includes PDF" do
      expect(Document::SUPPORTED_CONTENT_TYPES).to include("application/pdf")
    end

    it "includes plain text" do
      expect(Document::SUPPORTED_CONTENT_TYPES).to include("text/plain")
    end

    it "includes DOCX" do
      expect(Document::SUPPORTED_CONTENT_TYPES).to include(
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
      )
    end

    it "includes markdown" do
      expect(Document::SUPPORTED_CONTENT_TYPES).to include("text/markdown")
    end
  end
end
