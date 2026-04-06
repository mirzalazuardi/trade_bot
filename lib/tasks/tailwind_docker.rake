if ENV["RAILS_ENV"] == "production" && File.exist?("app/assets/builds/tailwind.css") && File.size("app/assets/builds/tailwind.css") > 25_000
  Rake::Task["tailwindcss:build"].clear
  namespace :tailwindcss do
    task :build do
      puts "Skipping Tailwind build — using pre-built CSS (#{File.size('app/assets/builds/tailwind.css')} bytes)"
    end
  end
end
