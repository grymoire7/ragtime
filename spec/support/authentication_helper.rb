module AuthenticationHelper
  def authenticate_request
    # Set up site password
    allow(Rails.application.credentials).to receive(:dig).and_call_original
    allow(Rails.application.credentials).to receive(:dig).with(:site_password).and_return("test-password")

    # Login via POST request to set session
    post "/auth/login", params: { password: "test-password" }, as: :json
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelper, type: :request
end
