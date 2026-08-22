# frozen_string_literal: true

# The /work specs assert that the real content ships — the figures come from production, git
# and a tracker, not from a factory — so they load it exactly the way a deploy does. Per
# example rather than per group: the suite is transactional, and seven inserts are cheap.
RSpec.shared_context 'when the cases are imported' do
  before { Cases::Importer.call }
end

# Same reasoning for the CV frame: the footer and the /work index assert the real identity
# ships, and the only place that identity exists is config/portfolio/cv.yml.
RSpec.shared_context 'when the cv is imported' do
  before { CV::Importer.call }
end
