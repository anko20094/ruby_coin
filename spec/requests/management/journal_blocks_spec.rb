# frozen_string_literal: true

require 'rails_helper'

describe 'the editor journal blocks endpoint', type: :request do
  let(:admin) { create(:user, role: :admin) }
  let(:path) { management_journal_blocks_path(locale: 'en') }

  context 'when an admin is signed in' do
    before { sign_in(admin) }

    it 'creates the block and answers with its sgid and rendered partial' do
      expect { post path, params: { kind: 'callout', payload: { tone: 'warn', body: 'This one bites.' } } }
        .to change(JournalBlock, :count).by(1)

      body = response.parsed_body
      expect(body['sgid']).to be_present
      expect(body['content']).to include('jn-callout--warn')
      expect(body['content']).to include('This one bites.')
    end

    it 'answers with the errors rather than an empty block' do
      expect { post path, params: { kind: 'embed', payload: { url: 'javascript:alert(1)' } } }
        .not_to change(JournalBlock, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['errors']).to be_present
    end

    it 'ignores payload keys that belong to another kind' do
      post path, params: { kind: 'code', payload: { source: 'def call; end', url: 'https://x.com', nonsense: 'x' } }

      expect(response).to have_http_status(:success)
      expect(JournalBlock.last.payload.keys).to contain_exactly('source', 'url')
    end
  end

  context 'when nobody is signed in' do
    it 'does not create anything' do
      expect { post path, params: { kind: 'callout', payload: { body: 'x' } } }
        .not_to change(JournalBlock, :count)

      # Devise's failure app runs at the middleware level, outside the locale around_action,
      # so the bounce always lands on the default locale. Pre-existing, worth knowing.
      expect(response).to redirect_to(new_user_session_path(locale: I18n.default_locale))
    end
  end

  context 'when a moderator is signed in' do
    it 'refuses, the same as it refuses them editing a post' do
      sign_in(create(:user, role: :moderator))

      expect { post path, params: { kind: 'callout', payload: { body: 'x' } } }
        .not_to change(JournalBlock, :count)
    end
  end
end
