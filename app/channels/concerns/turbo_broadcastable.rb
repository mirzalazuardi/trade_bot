# frozen_string_literal: true

module TurboBroadcastable
  extend ActiveSupport::Concern

  class_methods do
    def broadcast_to_live(channel, **attributes)
      broadcast = "dashboard:#{Current.user.id}"
      ActionCable.server.broadcast(broadcast, attributes)
    end
  end
end
