Rails.application.config.after_initialize do
  Strategy::Registry.register("rsi_reversal", Strategy::RSIReversal)
  Strategy::Registry.register("macd_crossover", Strategy::MACDCrossover)
end
