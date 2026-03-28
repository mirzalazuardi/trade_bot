admin_email = ENV.fetch("ADMIN_EMAIL", "admin@tradebot.local")
admin_password = ENV.fetch("ADMIN_PASSWORD", "changeme123")

User.find_or_create_by!(email_address: admin_email) do |user|
  user.password = admin_password
  user.password_confirmation = admin_password
  puts "Created admin user: #{admin_email}"
end
