# frozen_string_literal: true

require 'rails_helper'

describe Statistics::PostViewsQuery, type: :query do
  subject(:result) { described_class.new.count }

  include_context 'when carrierwave cleanup'

  context 'when data exist' do
    let!(:post_first) { create(:post) }
    let!(:post_second) { create(:post) }

    before do
      visit_one = create(:ahoy_visit)
      visit_two = create(:ahoy_visit)

      create(:ahoy_event, visit_id: visit_one.id, name: 'Viewed Post',
                          properties: { post_id: post_first.id, title: 'the title it had then' })
      create(:ahoy_event, visit_id: visit_two.id, name: 'Viewed Post',
                          properties: { post_id: post_first.id, title: 'the title it has now' })
      create(:ahoy_event, visit_id: visit_two.id, name: 'Viewed Post',
                          properties: { post_id: post_second.id })
    end

    # It used to group by the whole properties blob, so the two views of post_first — recorded
    # under two different titles — came back as two separate rows with one view each.
    it 'counts a post once however its title has changed' do
      expect(result).to eq([[post_first, 2], [post_second, 1]])
    end

    it 'hands back the post itself, so the screen reads the current title' do
      expect(result.first.first).to be_a(Post)
    end

    it 'ignores an event whose post has since been deleted' do
      create(:ahoy_event, name: 'Viewed Post', properties: { post_id: 999_999 })

      expect(result.sum(&:last)).to eq(3)
    end
  end

  context 'when there is no data' do
    it 'returns nothing rather than raising' do
      expect(result).to eq([])
    end
  end
end
