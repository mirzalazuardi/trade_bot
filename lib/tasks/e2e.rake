namespace :e2e do
  desc "Run Playwright E2E tests"
  task :test do
    puts "Starting E2E tests..."
    puts "Make sure the Rails server is running at http://localhost:3000"
    puts ""

    system "ruby test/system_test_runner.rb"
  end
end
