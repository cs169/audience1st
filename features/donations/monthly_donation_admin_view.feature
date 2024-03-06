@javascript
Feature: allow recurring donations
    As an admin
    So that customers can setup recurring donations
    I want to allow recurring donations

Background:

    Given I am logged in as administrator
    And I visit the admin:settings page

Scenario: Allow Monthly Recurring Donations
    When I set "Allow Recurring Donations" to "Yes"
    And I press "Update Settings"
    And I should see "Update successful"
    Then the radio button to select the default donation type should be "visible"
    When I go to the donation default page
    Then I should see "frequency"



Scenario: Disallow Monthly Recurring Donations
    When I am logged in as administrator
    And I visit the admin:settings page
    And I set "Allow Recurring Donations" to "No"
    And I press "Update Settings"
    Then the radio button to select the default donation type should be "hidden"
    

Scenario: Customer Shouldn't See Monthly Option
    When I switch to customer "Joe Mallon"
    And I go to the quick donation page
    And I should not see "Donation frequency"