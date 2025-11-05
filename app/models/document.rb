class Document < ApplicationRecord
  has_one_attached :file
  has_many :chunks, -> { order(position: :asc) }, dependent: :destroy

  enum :status, {
    pending: "pending",
    processing: "processing",
    completed: "completed",
    failed: "failed"
  }, default: :pending

  validates :title, presence: true
  validates :filename, presence: true
  validates :content_type, presence: true
  validates :file_size, presence: true, numericality: { greater_than: 0 }

  # Supported content types for document processing
  SUPPORTED_CONTENT_TYPES = [
    "application/pdf",
    "text/plain",
    "text/markdown",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
  ].freeze

  def supported_format?
    SUPPORTED_CONTENT_TYPES.include?(content_type)
  end

  def pdf?
    content_type == "application/pdf"
  end

  def text?
    content_type == "text/plain"
  end

  def docx?
    content_type == "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
  end

  def markdown?
    content_type == "text/markdown"
  end
end
