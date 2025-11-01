class DocumentsController < ApplicationController
  before_action :set_document, only: [:show, :destroy]

  # GET /documents
  # List all documents
  def index
    @documents = Document.order(created_at: :desc)
    render json: @documents.as_json(
      only: [:id, :title, :filename, :content_type, :file_size, :status, :processed_at, :created_at],
      methods: [:supported_format?],
      include: {
        chunks: { only: [:id] }
      }
    ).map { |doc|
      doc.merge(chunk_count: doc["chunks"].length).except("chunks")
    }
  end

  # GET /documents/:id
  # Show a single document with its chunks
  def show
    render json: @document.as_json(
      only: [:id, :title, :filename, :content_type, :file_size, :status, :processed_at, :created_at],
      methods: [:supported_format?],
      include: {
        chunks: {
          only: [:id, :position, :token_count, :content],
          methods: []
        }
      }
    )
  end

  # POST /documents
  # Upload a new document
  def create
    # Handle both nested (document[file]) and flat (file) parameter structures
    file = params.dig(:document, :file) || params[:file]

    unless file.present?
      return render json: { error: "No file provided" }, status: :unprocessable_content
    end

    title = params[:title] || params.dig(:document, :title) || file.original_filename

    @document = Document.new(
      title: title,
      filename: file.original_filename,
      content_type: file.content_type,
      file_size: file.size,
      status: :pending
    )

    @document.file.attach(file)

    if @document.save
      # Enqueue background job to process the document
      ProcessDocumentJob.perform_later(@document.id)

      render json: @document.as_json(
        only: [:id, :title, :filename, :content_type, :file_size, :status, :created_at]
      ), status: :created
    else
      render json: { errors: @document.errors.full_messages }, status: :unprocessable_content
    end
  end

  # DELETE /documents/:id
  # Delete a document and all its chunks
  def destroy
    @document.destroy
    head :no_content
  end

  private

  def set_document
    @document = Document.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Document not found" }, status: :not_found
  end
end
