# frozen_string_literal: true

require 'rails_helper'

describe 'the admin tag list past its last page', type: :request do
  before { sign_in create(:user, role: :admin) }

  it 'sends a page past the end to the last one' do
    create_list(:tag, 9)

    get management_tags_path(locale: 'en', page: 9)

    expect(response).to redirect_to(management_tags_path(locale: 'en', page: 2))
  end

  it 'renders the last page itself' do
    create_list(:tag, 9)

    get management_tags_path(locale: 'en', page: 2)

    expect(response).to be_successful
  end
end
