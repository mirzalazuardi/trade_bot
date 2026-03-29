require_relative "playwright_helper"

class SystemTest < ActionDispatch::IntegrationTest
  BASE_URL = ENV["TEST_BASE_URL"] || "http://localhost:3000"

  def self.test_order
    :random
  end

  def visit(path)
    PlaywrightHelper.visit("#{BASE_URL}#{path}")
  end

  def fill(selector, value)
    PlaywrightHelper.fill(selector, value)
  end

  def click(selector)
    PlaywrightHelper.click(selector)
  end

  def assert_text(expected)
    PlaywrightHelper.assert_text(expected)
  end

  def assert_selector(selector)
    PlaywrightHelper.assert_selector(selector)
  end

  def wait_for_selector(selector)
    PlaywrightHelper.wait_for_selector(selector)
  end

  def teardown
    PlaywrightHelper.cleanup
  end

  def sign_in(user = nil)
    user ||= User.first || create_user
    visit "/session/new"
    wait_for_selector "form"
    fill "input[name='email_address']", user.email_address
    fill "input[name='password']", "password"
    click "button[type='submit']"
  end

  def users(fixture_name)
    User.find_by(email_address: "#{fixture_name}@example.com") || User.create!(email_address: "#{fixture_name}@example.com", password: "password")
  end

  def bots(fixture_name)
    user = users(:one)
    case fixture_name.to_sym
    when :one
      Bot.find_or_create_by!(exchange_name: "binance", pair: "BTC/USDT") do |b|
        b.user = user
        b.strategy = "rsi_reversal"
        b.mode = "auto"
        b.status = "active"
        b.ai_enabled = false
      end
    when :two
      user2 = users(:two)
      Bot.find_or_create_by!(exchange_name: "oanda", pair: "EUR/USD") do |b|
        b.user = user2
        b.strategy = "macd_crossover"
        b.mode = "semi_auto"
        b.status = "paused"
        b.ai_enabled = true
      end
    when :paper
      Bot.find_or_create_by!(exchange_name: "binance", pair: "BTC/USDT") do |b|
        b.user = user
        b.strategy = "rsi_reversal"
        b.mode = "paper_trade"
        b.status = "active"
        b.ai_enabled = false
      end
    else
      raise "Unknown fixture: #{fixture_name}"
    end
  end

  def ml_models(fixture_name)
    user = users(:one)
    case fixture_name.to_sym
    when :one
      MlModel.find_or_create_by!(name: "test_model", version: 1, user: user) do |m|
        m.model_type = "lightgbm"
        m.status = "testing"
        m.training_date = Date.today
      end
    when :two
      MlModel.find_or_create_by!(name: "test_model", version: 2, user: user) do |m|
        m.model_type = "onnx"
        m.status = "active"
        m.training_date = Date.today - 1.day
      end
    else
      raise "Unknown fixture: #{fixture_name}"
    end
  end

  private

  def create_user
    User.create!(email_address: "test_#{Time.now.to_i}@example.com", password: "password")
  end
end
