@time
Feature: purchase tickets after performance starts

  As a customer attending a streaming performance
  So that I can still watch if I arrive a bit late
  I want to purchase tickets after the performance has started

  Background: a performance set up for at least some late sales

    Given a show "Chicago" with the following tickets available:
      | showdate         | type           | qty | price | sales_cutoff |
      | Jan 1, 2021, 8pm | Early purchase | 100 | $25   |           10 |
      | Jan 1, 2021, 8pm | Late purchase  | 100 | $23   |          -10 |
    And it is currently Jan 1, 2021, 8:05pm

  Scenario: some redemptions allow late sales

    When I go to the store page
    Then the "Early purchase - $25.00" menu should have options: 0
    When I select "1" from "Late purchase - $23.00"
    And I proceed to checkout
    Then the cart total price should be $23.00

  Scenario: too late for any redemptions

    Given it is currently Jan 1, 2021, 8:30pm
    When I go to the store page
    Then the "Early purchase - $25.00" menu should have options: 0
    And  the "Late purchase - $23.00" menu should have options: 0