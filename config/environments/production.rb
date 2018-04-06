# Settings specified here will take precedence over those in config/environment.rb

# The production environment is meant for finished, "live" apps.
# Code is not reloaded between requests
config.cache_classes = true

# Full error reports are disabled and caching is turned on
config.action_controller.consider_all_requests_local = false
config.action_controller.perform_caching             = true
#config.action_view.cache_template_loading            = true

config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
  :user_name => 'apikey',
  :password => Figaro.env.sendgrid_api_value!,
  :domain   => 'audience1st.com',
  :address  => 'smtp.sendgrid.net',
  :port     => 587,
  :enable_starttls_auto => true,
  :authentication => :plain
}

# See everything in the log (default is :info)
config.log_level = :info

# Use a different logger for distributed setups
# config.logger = SyslogLogger.new

# Use a different cache store in production
# config.cache_store = :mem_cache_store

# Enable serving of images, stylesheets, and javascripts from an asset server
# config.action_controller.asset_host = "http://assets.example.com"

# Disable delivery errors, bad email addresses will be ignored
# config.action_mailer.raise_delivery_errors = false

# Enable threaded mode
# config.threadsafe!

# NewRelic performance monitoring
#config.gem "newrelic_rpm"

# Remote exception notification
ExceptionNotifier.configure_exception_notifier do |config|
  config[:sender_address] =  %("EXCEPTION NOTIFIER" <bugs@audience1st.com>)
  config[:exception_recipients] =  %w(armandofox@gmail.com)
end
