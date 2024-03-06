 Given /the season start date is (.*)$/ do |date|
   d = Date.parse(date)
   Option.first.update_attributes!(:season_start_month => d.month, :season_start_day => d.day)
 end
 
 When /^I fill in all valid options$/ do
   opts = {
     'venue' => "Test Theater",
     'advance_sales_cutoff' => "60",
     'nearly_sold_out_threshold' => "80",
     'cancel_grace_period' => "1440",
     'send_birthday_reminders' => "0",
     'terms_of_sale' => 'Sales Final',
     'precheckout_popup' => 'Please double check dates',
     'venue_homepage_url' => 'http://test.org'
   }
   opts.each_pair do |opt,val|
     fill_in "option[#{opt}]", :with => val
   end
 end
 
 Given /^the (boolean )?setting "(.*)" is "(.*)"$/ do |bool,opt,val|
   val = !!(val =~ /true/i) if bool
   Option.first.update_attributes!(opt.downcase.gsub(/\s+/, '_') => val)
 end

 When /I upload the email template "(.*)"/ do |filename|
   within '#edit_options_form' do
     attach_file 'html_email_template', "#{TEST_FILES_DIR}/email/#{filename}", :visible => false
     click_button 'Update Settings'
   end
 end

 Then /^the setting "(.*)" should be "(.*)"$/ do |opt,val|
   expect(Option.send(opt.tr(' ','').underscore)).to eq(val)
 end

 # Step defintions for testing the recurring donation feature
 When /I set "(.*)" to "(.*)"/ do |setting_name, value|
  if value == 'Yes'
    value = true
  elsif value == 'No'
    value = false
  end
  # puts Option.find(1).read_attribute(:allow_recurring_donations)
  # option = Option.find(1)
  # option.update_attribute(setting_name.parameterize.underscore.to_sym, value)
  Option.first.update_attributes!(setting_name.parameterize.underscore.to_sym => value)


  # recurring_donation_select = page.find(:css, "#allow_recurring_donations_select")
  # recurring_donation_select.click
  # byebug
  # puts recurring_donation_select.find(:xpath, 'Yes')
 end

 Then /the radio button to select the default donation type should be "(.*)"/ do |value|
  if value == 'visible'
    value = true
  elsif value == 'hidden'
    value = false
  end
  # puts Option.find(1).read_attribute(:allow_recurring_donations)
  # radio = page.find(:css, "#default_donation_type_form_row", visible: false)
  expect(page).to have_selector('#default_donation_type_form_row', visible: true)
 end

 Then /the radio button to select the default donation type should be set to "(.*)"/ do |value|
  # puts page.find(:css, '#default_donation_type_form_row')
  expect(page).to have_css('#default_donation_type_form_row', visible: value)
 end

 Given /admin has allowed recurring donations/ do 
  Option.first.update_attributes!(:allow_recurring_donations => true)
 end

 When /I select monthly in the donation frequency radio button/ do 
   

