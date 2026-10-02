# frozen_string_literal: true

# The /work specs assert that the real content ships — the figures come from production, git
# and a tracker, not from a factory — so they load it exactly the way a deploy does. Per
# example rather than per group: the suite is transactional, and seven inserts are cheap.
RSpec.shared_context 'when the cases are imported' do
  before { Cases::Importer.call }
end
