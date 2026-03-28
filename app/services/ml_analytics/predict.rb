module MlAnalytics
  class Predict
    @@model_cache = {}

    def self.model_cache
      @@model_cache
    end

    def self.call(bot:, signal:)
      new(bot: bot, signal: signal).predict
    end

    def initialize(bot:, signal:)
      @bot = bot
      @signal = signal
    end

    def predict
      return Prediction.new(confidence: 0.5, prediction: "hold", reason: "No ML model") unless @bot.ml_model_id

      ml_model = MlModel.find(@bot.ml_model_id)
      return Prediction.new(confidence: 0.5, prediction: "hold", reason: "Model not active") unless ml_model.active?

      features = load_features(ml_model)
      return Prediction.new(confidence: 0.5, prediction: "hold", reason: "Insufficient data") if features.nil? || features.empty?

      model = load_model(ml_model)
      return Prediction.new(confidence: 0.5, prediction: "hold", reason: "Model load failed") unless model

      raw_confidence = run_inference(model, features, ml_model.model_type)
      confidence = normalize_confidence(raw_confidence)

      MlPredictionLog.log_prediction(
        bot: @bot,
        model: ml_model,
        confidence: confidence,
        signal_type: @signal.type,
        features: features
      )

      Prediction.new(
        confidence: confidence,
        prediction: map_to_signal(confidence),
        reason: "ML prediction: #{confidence.round(2)}"
      )
    end

    def load_features(ml_model)
      Features::Pipeline.call(
        exchange: @bot.exchange_name,
        pair: @bot.pair,
        ml_model_id: ml_model.id
      )
    end

    private

    def load_model(ml_model)
      return @@model_cache[ml_model.id] if @@model_cache.key?(ml_model.id)

      path = ml_model.file_path
      return nil unless path && File.exist?(path)

      model = case ml_model.model_type
      when "lightgbm" then load_lightgbm(path)
      when "onnx" then load_onnx(path)
      else nil
      end

      @@model_cache[ml_model.id] = model if model
      model
    rescue => e
      Rails.logger.warn "Failed to load model #{ml_model.id}: #{e.message}"
      nil
    end

    def load_lightgbm(path)
      LightGBM::Model.from_file(path)
    rescue NameError
      nil
    end

    def load_onnx(path)
      ONNXRuntime::Model.new(path)
    rescue NameError
      nil
    end

    def run_inference(model, features, model_type)
      case model_type
      when "lightgbm"
        predict_proba = model.predict(features)
        predict_proba.is_a?(Array) ? predict_proba[0] : predict_proba
      when "onnx"
        input = { "input" => features.reshape(1, -1) }
        output = model.run(input)
        output["output"]&.first || 0.5
      else
        0.5
      end
    end

    def normalize_confidence(raw)
      raw.clamp(0.0, 1.0)
    end

    def map_to_signal(confidence)
      if confidence >= @bot.ml_high_threshold
        @signal.type
      elsif confidence >= @bot.ml_low_threshold
        @signal.type
      else
        "hold"
      end
    end

    Prediction = Data.define(:confidence, :prediction, :reason) do
      def initialize(confidence:, prediction:, reason:)
        super
      end
    end
  end
end
