require "csv"
require "net/http"
require "json"

namespace :ml do
  desc "Fetch historical candles from Binance (no API key needed)"
  task :fetch_candles, [ :pair, :interval, :days ] => :environment do |_t, args|
    pair = args[:pair] || "BTC/USDT"
    interval = args[:interval] || "1h"
    days = (args[:days] || 90).to_i

    symbol = pair.delete("/").upcase
    exchange = "binance"

    puts "Fetching #{days} days of #{interval} candles for #{pair} from Binance..."

    base_url = "https://api.binance.com/api/v3/klines"
    end_time = (Time.now.to_f * 1000).to_i
    start_time = ((Time.now - days.days).to_f * 1000).to_i
    total = 0

    current_start = start_time
    while current_start < end_time
      uri = URI(base_url)
      uri.query = URI.encode_www_form(
        symbol: symbol,
        interval: interval,
        startTime: current_start,
        limit: 1000
      )

      response = Net::HTTP.get_response(uri)
      unless response.is_a?(Net::HTTPSuccess)
        puts "API error: #{response.code} #{response.body[0..200]}"
        break
      end

      klines = JSON.parse(response.body)
      break if klines.empty?

      klines.each do |k|
        ts = k[0].to_i / 1000

        Candle.find_or_initialize_by(
          exchange_name: exchange,
          pair: pair,
          interval: interval,
          timestamp: ts
        ).update!(
          open: k[1].to_d,
          high: k[2].to_d,
          low: k[3].to_d,
          close: k[4].to_d,
          volume: k[5].to_d,
          closed: true
        )
      end

      total += klines.size
      current_start = klines.last[0].to_i + 1
      print "\r  #{total} candles fetched..."
      sleep 0.2  # rate limit
    end

    puts "\nDone! #{total} candles saved for #{pair}"
    puts "Total candles in DB: #{Candle.where(exchange_name: exchange, pair: pair, interval: interval).count}"
  end

  desc "Train model: fetch data, export CSV, run Python training"
  task :train, [ :pair, :days ] => :environment do |_t, args|
    pair = args[:pair] || "BTC/USDT"
    days = (args[:days] || 90).to_i
    exchange = "binance"
    interval = "1h"

    puts "=" * 60
    puts "ML Training Pipeline"
    puts "=" * 60

    # Step 1: Fetch candles if needed
    existing = Candle.where(exchange_name: exchange, pair: pair, interval: interval).count
    if existing < 100
      puts "\n[1/4] Fetching candles from Binance..."
      Rake::Task["ml:fetch_candles"].invoke(pair, interval, days)
    else
      puts "\n[1/4] Using #{existing} existing candles"
    end

    # Step 2: Export to CSV
    puts "\n[2/4] Exporting training data..."
    from_date = days.days.ago.to_date
    to_date = Date.today

    candles = Candle.where(exchange_name: exchange, pair: pair, interval: interval)
                   .where("timestamp >= ?", from_date.to_time.to_i)
                   .order(:timestamp)

    csv_path = Rails.root.join("storage/ml_training_data/#{exchange}_#{pair.delete("/")}_training.csv")
    csv_path.dirname.mkpath

    CSV.open(csv_path, "w") do |csv|
      csv << %w[timestamp open high low close volume]
      candles.each do |c|
        csv << [ c.timestamp, c.open.to_f, c.high.to_f, c.low.to_f, c.close.to_f, c.volume.to_f ]
      end
    end
    puts "  Exported #{candles.size} candles to #{csv_path}"

    # Step 3: Run Python training
    puts "\n[3/4] Training LightGBM model..."
    script = Rails.root.join("scripts/train_model.py")
    model_dir = Rails.root.join("storage/ml_models")
    model_dir.mkpath

    result = system("python3", script.to_s, csv_path.to_s, model_dir.to_s)
    unless result
      puts "  ✗ Python training failed. Run manually:"
      puts "    python3 #{script} #{csv_path} #{model_dir}"
      next
    end

    model_path = model_dir.join("signal_model.txt")
    metadata_path = model_dir.join("metadata.json")

    unless model_path.exist?
      puts "  ✗ Model file not created"
      next
    end

    # Step 4: Create/update MlModel record
    puts "\n[4/4] Registering model in database..."
    metadata = JSON.parse(File.read(metadata_path)) rescue {}
    user = User.first

    model = MlModel.find_or_initialize_by(user: user, name: metadata["name"] || "Signal Filter")
    model.update!(
      version: (model.version || 0) + 1,
      model_type: :lightgbm,
      status: :testing,
      file_path: model_path.to_s,
      training_date: Date.today,
      feature_list: metadata["feature_list"] || %w[open high low close volume rsi macd volatility],
      performance_metrics: metadata["performance_metrics"] || {}
    )

    puts "  ✓ Model saved: #{model.name} v#{model.version} (status: testing)"
    puts "\n" + "=" * 60
    puts "Done! To activate:"
    puts "  bin/rails runner 'MlModel.last.update!(status: :active)'"
    puts "=" * 60
  end

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
