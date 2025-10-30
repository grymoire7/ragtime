# Stub for RubyLLM in test environment
# Define the module structure so we can mock it in specs
module RubyLLM
  class Client
    def self.embed(text, model:)
      # This will be mocked in specs
      raise NotImplementedError, "RubyLLM::Client.embed should be mocked in tests"
    end
  end
end
