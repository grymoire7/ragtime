class Message < ApplicationRecord
  acts_as_message
  has_many_attached :attachments

  # Note: broadcasts_to removed because Vue.js frontend uses HTTP polling
  # instead of ActionCable for real-time updates. The automatic broadcasts
  # were causing SolidCable schema errors and aren't needed.

  # broadcast_append_chunk also removed - not used with polling architecture
end
