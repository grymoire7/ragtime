FactoryBot.define do
  factory :document do
    title { "Test Document" }
    filename { "test.pdf" }
    content_type { "application/pdf" }
    file_size { 1024 }
    status { :pending }
    processed_at { nil }

    # Create a test file attachment
    after(:build) do |document|
      document.file.attach(
        io: StringIO.new("test content"),
        filename: document.filename,
        content_type: document.content_type
      )
    end

    trait :text_file do
      filename { "test.txt" }
      content_type { "text/plain" }
    end

    trait :docx_file do
      filename { "test.docx" }
      content_type { "application/vnd.openxmlformats-officedocument.wordprocessingml.document" }
    end

    trait :processing do
      status { :processing }
    end

    trait :completed do
      status { :completed }
      processed_at { Time.current }
    end

    trait :failed do
      status { :failed }
    end

    trait :with_chunks do
      after(:create) do |document|
        create_list(:chunk, 3, document: document)
      end
    end
  end
end
