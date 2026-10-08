# frozen_string_literal: true

# Renders the share cards; what goes on them and how is OgCards (app/services/og_cards.rb).
namespace :og do
  desc 'Render the Open Graph share cards into public/og'
  task cards: :environment do
    browser = OgCards.chrome
    abort "no Chrome found — set CHROME_BIN (tried: #{OgCards::CHROME_CANDIDATES.join(', ')})" if browser.nil?

    written = OgCards.render_all(browser)

    puts "wrote #{written.size} cards:"
    written.each { |path| puts "  #{path.relative_path_from(Rails.root)} (#{(path.size / 1024.0).round} KB)" }
  rescue OgCards::RenderError => e
    abort e.message
  end
end
