# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ahoy::EventProcess do
  subject(:result) { described_class.call(ahoy, post, request) }

  let(:post) { create(:post) }
  let(:session) { { last_visit: nil } }
  let(:request) { instance_double(ActionDispatch::Request, session: session) }
  let(:ahoy) { Ahoy::Tracker.new(visit_token: ahoy_visit.visitor_token) }
  let(:ahoy_visit) { build_stubbed(:ahoy_visit) }

  describe '#call' do
    it 'tracks a visit and an event' do
      expect(Ahoy::Visit.count).to eq(0)
      expect(Ahoy::Event.count).to eq(0)

      result

      expect(Ahoy::Visit.count).to eq(1)
      expect(Ahoy::Event.count).to eq(1)
    end

    it 'stores the name and the id the statistics and Post.best read back' do
      result

      expect(Ahoy::Event.last).to have_attributes(name: 'Viewed Post', properties: include('post_id' => post.id))
    end

    it 'remembers the view under the key the controller checks' do
      result

      expect(session[described_class.session_key_for(post)]).to be_within(5).of(Time.zone.now.to_i)
    end
  end

  # The session is a cookie, and a cookie is 4 KB: one key per subject that is never removed
  # turns a long reading session into a 500 on the response.
  describe 'what it leaves in the session' do
    let(:now) { Time.zone.now.to_i }
    let(:old_key) { 'last_visit_post_1' }
    let(:fresh_key) { 'last_visit_case_2' }
    let(:session) do
      { 'session_id' => 'abc', 'last_visit_post_1' => now - 25.hours.to_i, 'last_visit_case_2' => now - 60 }
    end

    it 'drops the keys whose 24 hours have passed' do
      result

      expect(session).not_to have_key(old_key)
    end

    it 'keeps the ones still inside the window, and everything that is not a view' do
      result

      expect(session).to include(fresh_key => now - 60, 'session_id' => 'abc')
    end

    it 'prunes the keys of the spelling that had no subject in it' do
      session['last_visit_7'] = now - 25.hours.to_i

      result

      expect(session).not_to have_key('last_visit_7')
    end

    context 'when a reader has opened more subjects than the cookie can carry' do
      let(:session) do
        (1..200).to_h { |id| ["last_visit_post_#{id + 1000}", now - 200 + id] }.merge('session_id' => 'abc')
      end

      it 'keeps a bounded number of them, newest first' do
        result

        tracked = session.keys.grep(/\Alast_visit_/)

        expect(tracked.size).to eq(described_class::MAX_TRACKED)
        expect(tracked).to include(described_class.session_key_for(post), 'last_visit_post_1200')
        expect(tracked).not_to include('last_visit_post_1001')
      end
    end
  end
end
