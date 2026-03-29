require "test_helper"

class TelegramCommandHandlerTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @bot = TelegramBot.new
  end

  test "processes /start command" do
    message = { "text" => "/start", "chat" => { "id" => "123" } }

    result = Telegram::CommandHandler.new(user: @user, message: message).process

    assert_nil result
  end

  test "processes /help command" do
    message = { "text" => "/help", "chat" => { "id" => "123" } }

    result = Telegram::CommandHandler.new(user: @user, message: message).process

    assert_nil result
  end

  test "processes /status command" do
    message = { "text" => "/status", "chat" => { "id" => "123" } }

    result = Telegram::CommandHandler.new(user: @user, message: message).process

    assert_nil result
  end

  test "processes unknown command" do
    message = { "text" => "/unknown", "chat" => { "id" => "123" } }

    result = Telegram::CommandHandler.new(user: @user, message: message).process

    assert_nil result
  end
end
