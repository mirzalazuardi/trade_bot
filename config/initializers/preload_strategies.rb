Rails.application.config.after_initialize do
  Strategy::RsiReversal
  Strategy::MacdCrossover
end
