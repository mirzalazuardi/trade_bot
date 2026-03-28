require "csv"

namespace :ml do
  desc "Export training data to CSV"
  task :export_training_data, [ :pair, :exchange, :from, :to ] => :environment do |_t, args|
    pair = args[:pair] || raise("Usage: rake ml:export_training_data[pair,exchange,from,to]")
    exchange = args[:exchange] || raise("Usage: rake ml:export_training_data[pair,exchange,from,to]")
    from_date = args[:from] ? Date.parse(args[:from]) : 30.days.ago.to_date
    to_date = args[:to] ? Date.parse(args[:to]) : Date.today

    candles = Candle.where(exchange_name: exchange, pair: pair)
                   .where("timestamp >= ?", from_date)
                   .where("timestamp <= ?", to_date + 1.day)
                   .order(:timestamp)

    unless candles.any?
      puts "No candle data found for #{exchange}/#{pair}"
      next
    end

    csv_path = Rails.root.join("storage/ml_training_data/#{exchange}_#{pair}_#{from_date}_#{to_date}.csv")
    csv_path.dirname.mkpath

    CSV.open(csv_path, "w") do |csv|
      csv << %w[timestamp open high low close volume rsi macd volatility]

      rsi_values = Indicators::RSI.call(candles, period: 14)
      macd_values = Indicators::MACD.call(candles)
      volatility_values = Features::RollingStatistics.volatility(candles, window: 20)

      candles.each_with_index do |c, i|
        csv << [
          c.timestamp.to_i,
          c.open,
          c.high,
          c.low,
          c.close,
          c.volume,
          rsi_values[i]&.round(4) || "",
          macd_values[:macd_line]&.dig(i)&.round(4) || "",
          volatility_values[i]&.round(6) || ""
        ]
      end
    end

    puts "Exported #{candles.size} candles to #{csv_path}"
  end

  desc "Validate Ruby feature computation against Python reference"
  task :validate_features, [ :pair, :exchange ] => :environment do |_t, args|
    pair = args[:pair] || raise("Usage: rake ml:validate_features[pair,exchange]")
    exchange = args[:exchange] || raise("Usage: rake ml:validate_features[pair,exchange]")

    candles = Candle.where(exchange_name: exchange, pair: pair)
                   .order(:timestamp)
                   .limit(100)

    unless candles.any?
      puts "No candle data found for #{exchange}/#{pair}"
      next
    end

    ref_csv = Rails.root.join("storage/ml_training_data/#{exchange}_#{pair}_validation.csv")
    unless File.exist?(ref_csv)
      puts "Reference CSV not found: #{ref_csv}"
      puts "Please generate reference data from Python first"
      next
    end

    rsi_values = Indicators::RSI.call(candles, period: 14)
    macd_values = Indicators::MACD.call(candles)
    volatility_values = Features::RollingStatistics.volatility(candles, window: 20)

    tolerance = 1e-6
    max_rsi_diff = 0
    max_macd_diff = 0
    max_vol_diff = 0

    CSV.foreach(ref_csv, headers: true).with_index do |row, i|
      next if i >= candles.size

      ruby_rsi = rsi_values[i]&.round(4) || 0
      ruby_macd = macd_values[:macd_line]&.dig(i)&.round(4) || 0
      ruby_vol = volatility_values[i]&.round(6) || 0

      py_rsi = row["rsi"].to_f.round(4) rescue 0
      py_macd = row["macd"].to_f.round(4) rescue 0
      py_vol = row["volatility"].to_f.round(6) rescue 0

      max_rsi_diff = [ (ruby_rsi - py_rsi).abs, max_rsi_diff ].max
      max_macd_diff = [ (ruby_macd - py_macd).abs, max_macd_diff ].max
      max_vol_diff = [ (ruby_vol - py_vol).abs, max_vol_diff ].max
    end

    puts "RSI max diff: #{max_rsi_diff}"
    puts "MACD max diff: #{max_macd_diff}"
    puts "Volatility max diff: #{max_vol_diff}"

    if max_rsi_diff < tolerance && max_macd_diff < tolerance && max_vol_diff < tolerance
      puts "✓ All features within tolerance"
    else
      puts "✗ Feature validation failed"
      exit 1
    end
  end
end
