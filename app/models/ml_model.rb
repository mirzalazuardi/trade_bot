class MlModel < ApplicationRecord
  validates :name, :version, :model_type, presence: true
  validates :version, uniqueness: { scope: :name }

  enum :status, { testing: "testing", active: "active", retired: "retired" }, prefix: true
  enum :model_type, { lightgbm: "lightgbm", onnx: "onnx" }, prefix: true

  scope :active_models, -> { where(status: :active) }
  scope :by_name, ->(name) { where(name: name) }

  def active?
    status == "active"
  end

  def retired?
    status == "retired"
  end

  def testing?
    status == "testing"
  end
end
