class Approval < ApplicationRecord
  belongs_to :user
  belongs_to :bot, foreign_key: :bot_id

  enum :status, { pending: "pending", approved: "approved", rejected: "rejected", expired: "expired" }, prefix: true

  validates :side, :quantity, :price, :pair, presence: true

  scope :pending_approvals, -> { where(status: :pending) }
  scope :expired_approvals, -> { where("expires_at < ?", Time.current) }

  def pending?
    status == "pending"
  end

  def approved?
    status == "approved"
  end

  def rejected?
    status == "rejected"
  end

  def expired?
    status == "expired" || (pending? && expires_at < Time.current)
  end

  def approve!
    update!(status: :approved)
  end

  def reject!
    update!(status: :rejected)
  end

  def expire!
    update!(status: :expired)
  end
end
