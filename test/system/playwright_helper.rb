require "playwright"

PLAYWRIGHT_CLI_PATH = "/Users/hermawan/.npm-global/bin/playwright"

module PlaywrightHelper
  extend self

  def browser
    return @_browser if @_browser

    execution = Playwright.create(playwright_cli_executable_path: PLAYWRIGHT_CLI_PATH)
    @_browser = execution.playwright.chromium.launch(headless: true)
    @_browser
  end

  def context
    @_context ||= browser.new_context
  end

  def page
    @_page ||= context.new_page
  end

  def cleanup
    @_page&.close
    @_context&.close
    @_browser&.close
    @_page = nil
    @_context = nil
    @_browser = nil
  rescue StandardError
    @_page = nil
    @_context = nil
    @_browser = nil
  end

  def screenshot(name = "screenshot")
    page.screenshot(path: "tmp/screenshots/#{name}.png")
  end

  def wait_for_selector(selector, timeout: 5000)
    page.wait_for_selector(selector, timeout: timeout)
  end

  def fill(selector, value)
    page.fill(selector, value)
  end

  def click(selector)
    page.click(selector)
  end

  def text_content(selector)
    page.text_content(selector)
  end

  def visit(url)
    page.goto(url)
  end

  def assert_text(expected)
    content = page.content
    raise "Expected to find '#{expected}' but it was not found" unless content.include?(expected)
  end

  def assert_selector(selector, timeout: 5000)
    wait_for_selector(selector, timeout: timeout)
  end
end
