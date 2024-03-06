@stubs_successful_credit_card_payment
@javascript
Feature: make a recurring donation through regular sales flow

Background:
  Given I am logged in as customer "Tom Foolery"
  Given admin has allowed recurring donations
  And I go to the quick donation page

Scenario: make donation
  Then I should see "frequency"
  When I select monthly in the donation frequency radio button
  When I fill in "donation" with "15"
  And I proceed to checkout
  Then I should be on the Checkout page
  And the cart should contain a donation of $15.00 to "General Fund"
  And the billing customer should be "Tom Foolery"
  When I place my order with a valid credit card
  Then I should be on the order confirmation page
  And I should see "You have paid a total of $15.00 by Credit card"
  And an email should be sent to customer "Tom Foolery" containing "A1 Staging Theater thanks you for your donation!"
  And customer "Tom Foolery" should have a donation of $15.00 to "General Fund"
  Then there should be a new row in the Recurring Donation model

