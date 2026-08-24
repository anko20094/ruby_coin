# frozen_string_literal: true

class Ahoy::Store < Ahoy::DatabaseStore
end

# set to true for JavaScript tracking
Ahoy.api = false

# set to true for geocoding (and add the geocoder gem to your Gemfile)
# we recommend configuring local geocoding as well
# see https://github.com/ankane/ahoy#geocoding
Ahoy.geocode = false
# Crawlers are not readers. Counting them wrote a visit row on every crawl — synchronously,
# in the request — and put their traffic into the same numbers the owner reads to decide what
# to write next.
Ahoy.track_bots = false
