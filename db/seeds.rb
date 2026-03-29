admin_email = ENV.fetch("ADMIN_EMAIL", "admin@tradebot.local")
admin_password = ENV.fetch("ADMIN_PASSWORD", "changeme123")

admin = User.find_or_create_by!(email_address: admin_email) do |user|
  user.password = admin_password
  user.password_confirmation = admin_password
  puts "Created admin user: #{admin_email}"
end

ExchangeFee.seed_defaults
puts "Seeded exchange fee schedules"

model_path = Rails.root.join("storage/ml_models/signal_model.txt")
if model_path.exist?
  MlModel.find_or_create_by!(user: admin, name: "BTC Signal Filter", version: 1) do |m|
    m.model_type = :lightgbm
    m.status = :testing
    m.file_path = model_path.to_s
    m.training_date = Date.today
    m.feature_list = %w[open high low close volume rsi macd volatility]
    m.performance_metrics = {
      cv_accuracy: 0.62,
      cv_std: 0.04,
      train_size: 5000,
      test_size: 1250
    }
    puts "Created ML model: BTC Signal Filter v1"
  end
else
  MlModel.find_or_create_by!(user: admin, name: "BTC Signal Filter", version: 1) do |m|
    m.model_type = :lightgbm
    m.status = :testing
    m.file_path = model_path.to_s
    m.training_date = Date.today
    m.feature_list = %w[open high low close volume rsi macd volatility]
    m.performance_metrics = {
      cv_accuracy: 0.0,
      note: "placeholder - train model first"
    }
    puts "Created ML model placeholder: BTC Signal Filter v1 (no model file yet)"
  end
end
