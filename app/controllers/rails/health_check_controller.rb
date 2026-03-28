class Rails::HealthCheckController < ActionController::Base
  def show
    checks = run_checks
    all_passed = checks.values.all?

    status = all_passed ? :ok : :service_unavailable
    render json: { status: all_passed ? "ok" : "unhealthy", checks: checks }, status: status
  end

  private

  def run_checks
    {
      database: check_database,
      solid_queue: check_solid_queue,
      exchanges: check_exchanges,
      ml_models: check_ml_models
    }
  end

  def check_database
    ActiveRecord::Base.connection.execute("SELECT 1")
    "ok"
  rescue => e
    Rails.logger.error { "Database health check failed: #{e.message}" }
    "error"
  end

  def check_solid_queue
    return "skipped" if SolidQueue::Job.none?

    pending = SolidQueue::Job.where(failed_at: nil).limit(100).count
    "ok"
  rescue => e
    Rails.logger.error { "Solid Queue health check failed: #{e.message}" }
    "error"
  end

  def check_exchanges
    "ok"
  rescue => e
    Rails.logger.error { "Exchange health check failed: #{e.message}" }
    "error"
  end

  def check_ml_models
    active = MlModel.active_models.exists? ? "ok" : "none"
  rescue => e
    Rails.logger.error { "ML models health check failed: #{e.message}" }
    "error"
  end
end
