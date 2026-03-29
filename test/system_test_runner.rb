#!/usr/bin/env ruby
ENV["RAILS_ENV"] ||= "test"

require "playwright"

require File.expand_path("../../config/environment", __FILE__)

require "rails/test_help"
require "minitest/autorun"
require File.expand_path("system/playwright_helper", __dir__)

Dir.glob("#{__dir__}/system/*_test.rb").each do |file|
  require file
end

puts "Starting E2E tests..."
puts "Make sure the Rails server is running at http://localhost:3000"
puts ""

Minitest.autorun
