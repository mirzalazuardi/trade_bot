exchanges_dir = Rails.root.join("app/models/exchanges")
Dir.glob(exchanges_dir.join("**/*.rb")).sort.each { |f| require f }

Exchanges::Registry.register("binance", Exchanges::Binance)
Exchanges::Registry.register("indodax", Exchanges::Indodax)
Exchanges::Registry.register("tokocrypto", Exchanges::Tokocrypto)
Exchanges::Registry.register("oanda", Exchanges::Oanda)
