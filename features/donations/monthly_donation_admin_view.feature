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
    Then the radio button to select the default donation type should be "visible"

Scenario: Disallow Monthly Recurring Donations

    When I set "Allow Recurring Donations" to "No"
    Then the radio button to select the default donation type should be "hidden"