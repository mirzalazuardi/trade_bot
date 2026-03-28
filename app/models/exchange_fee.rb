class ExchangeFee < ApplicationRecord
  validates :exchange_name, presence: true, uniqueness: true

  def self.seed_defaults
    find_or_create_by!(exchange_name: "binance") do |f|
      f.maker_rate = 0.001
      f.taker_rate = 0.001
      f.spread_based = false
      f.typical_spreads = { "BTC/USDT" => 0.01, "ETH/USDT" => 0.01 }
    end

    find_or_create_by!(exchange_name: "indodax") do |f|
      f.maker_rate = 0
      f.taker_rate = 0.003
      f.spread_based = false
      f.typical_spreads = {}
    end

    find_or_create_by!(exchange_name: "tokocrypto") do |f|
      f.maker_rate = 0.001
      f.taker_rate = 0.001
      f.spread_based = false
      f.typical_spreads = { "BTC/USDT" => 0.01, "ETH/USDT" => 0.01 }
    end

    find_or_create_by!(exchange_name: "oanda") do |f|
      f.maker_rate = 0
      f.taker_rate = 0
      f.spread_based = true
      f.typical_spreads = { "EUR/USD" => 0.11, "GBP/USD" => 0.15, "XAU/USD" => 2.5 }
    end
  end

  def fee_schedule
    Exchanges::ValueObjects::FeeSchedule.new(
      maker_rate: maker_rate,
      taker_rate: taker_rate,
      spread_based: spread_based,
      typical_spreads: typical_spreads
    )
  end
end
