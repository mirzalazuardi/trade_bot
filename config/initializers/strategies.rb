Rails.application.config.after_initialize do
  Strategy::Registry.register("rsi_reversal", Strategy::RsiReversal)
  Strategy::Registry.register("macd_crossover", Strategy::MacdCrossover)
end
