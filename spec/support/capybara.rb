# frozen_string_literal: true

# Capybara is here for its matchers, which the ViewComponent specs use (spec/support/
# view_component.rb). There are no system specs, so there is no browser driver configured —
# adding `selenium-webdriver` back, a driver and a `driven_by` line is the whole setup when
# there are.
