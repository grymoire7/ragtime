module ApplicationHelper
  def current_ruby_llm_config
    Rails.configuration.x.ruby_llm[Rails.env.to_sym]
  end
  
  def ruby_llm_chat_model
    return unless config = current_ruby_llm_config
    {
      model: config[:chat][:model],
      provider: config[:chat][:provider]
    }
  end
  
  def ruby_llm_embedding_model
    return unless config = current_ruby_llm_config
    {
      model: config[:embedding][:model],
      provider: config[:embedding][:provider]
    }
  end
end
