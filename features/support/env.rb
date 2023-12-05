require 'simplecov' # automatically reads APP_ROOT/.simplecov for config options
SimpleCov.start 'rails'

# IMPORTANT: This file is generated by cucumber-rails - edit at your own peril.
# It is recommended to regenerate this file in the future when you upgrade to a 
# newer version of cucumber-rails. Consider adding your own code to a new file 
# instead of editing this one. Cucumber will automatically load all features/**/*.rb
# files.


ENV["RAILS_ENV"] = "test"
require File.expand_path(File.dirname(__FILE__) + '/../../config/environment')

TEST_FILES_DIR = File.join(Rails.root, 'spec', 'test_files') unless defined?(TEST_FILES_DIR)

require 'cucumber/rails'
require 'webdrivers'

# This is email_spec
require 'email_spec/cucumber'

# Capybara defaults to XPath selectors rather than Webrat's default of CSS3. In
# order to ease the transition to Capybara we set the default here. If you'd
# prefer to use XPath just remove this line and adjust any selectors in your
# steps to use the XPath syntax.
Capybara.default_selector = :css
Capybara.server = :webrick
Capybara.register_driver :selenium do |app|
  Webdrivers::Chromedriver.required_version = '119.0.6045.105'
  webdriver_args = %w[--headless --no-sandbox --disable-gpu --window-size=1024,1024]
  options = Selenium::WebDriver::Chrome::Options.new(
    args: webdriver_args
  )
  # When an "unexpected" alert/confirm is displayed, accept it (ie user clicks OK).
  # Expected ones can be handled with accept_alert do...end or accept_confirm do...end
  options.add_option(:unhandled_prompt_behavior, :accept)
  Capybara::Selenium::Driver.new(
    app,
    browser: :chrome,
    capabilities: options,
    clear_session_storage: true,
    clear_local_storage: true)
end

# If you set this to false, any error raised from within your app will bubble 
# up to your step definition and out to cucumber unless you catch it somewhere
# on the way. You can make Rails rescue errors and render error pages on a
# per-scenario basis by tagging a scenario or feature with the @allow-rescue tag.
#
# If you set this to true, Rails will rescue all errors and render error
# pages, more or less in the same way your application would behave in the
# default production environment. It's not recommended to do this for all
# of your scenarios, as this makes it hard to discover errors in your application.
ActionController::Base.allow_rescue = false

# If you set this to true, each scenario will run in a database transaction.
# You can still turn off transactions on a per-scenario basis, simply tagging 
# a feature or scenario with the @no-txn tag. If you are using Capybara,
# tagging with @culerity or @javascript will also turn transactions off.
#
# If you set this to false, transactions will be off for all scenarios,
# regardless of whether you use @no-txn or not.
#
# Beware that turning transactions off will leave data in your database 
# after each scenario, which can lead to hard-to-debug failures in 
# subsequent scenarios. If you do this, we recommend you create a Before
# block that will explicitly put your database in a known state.
Cucumber::Rails::World.use_transactional_fixtures = false

DatabaseCleaner.strategy = :transaction
Cucumber::Rails::Database.javascript_strategy = :truncation

World(RSpec::Mocks::ExampleMethods)

Before do
  # If multi-tenancy in use, create a default tenant for testing. Since default URLs
  #  generated by Cucumber begin with www, make that the tenant name.
  unless Figaro.env.tenant_names.blank?
    Apartment::Tenant.drop('www') rescue nil
    Apartment::Tenant.create('www')
    Apartment::Tenant.switch!('www')
  end

  # static seed data - root user, venue options, etc.
  load File.join(Rails.root, 'db', 'seeds.rb')
  
  # make rspec mocks/stubs work
  #require 'cucumber/rspec/doubles'
  RSpec::Mocks::setup

  # stub the client (JS) calls to Stripe
  FakeStripe.stub_stripe

  # Allow testing of emails
  ActionMailer::Base.delivery_method = :test
  ActionMailer::Base.perform_deliveries = true
  ActionMailer::Base.deliveries.clear

end

After do
  WebMock.reset!
  begin
    RSpec::Mocks.verify
  ensure
    RSpec::Mocks.teardown
  end
end

# It is always 1/1/2010, except for tests that specifically manipulate time
Before('not @time') do
  @base_time = Time.zone.parse('January 1, 2010')
  Timecop.travel @base_time
end

# Stub Stripe for certain scenarios
Before('@stubs_successful_credit_card_payment') do
  stub_request(:post, 'stripe.com')
  Store::Payment.stub(:pay_with_credit_card) do |order|
    order.update_attribute(:authorization, 'ABC123')
    true
  end
end

Before('@stubs_failed_credit_card_payment') do
  Store::Payment.stub(:pay_with_credit_card) do |order|
    order.authorization = nil
    order.errors.add :base,"Credit card payment error: Forced failure in test mode"
    nil
  end
end

Before('@stubs_successful_refund') do
  Store::Payment.stub(:refund_credit_card).and_return(true)
end

Before('@stubs_failed_refund') do
  Store.stub(:refund_credit_card).and_raise(Stripe::StripeError.new("Refund failed in test mode"))
end

World(FactoryBot::Syntax::Methods)
World(ActionView::Helpers::NumberHelper)
World(ActionView::Helpers::TextHelper)

