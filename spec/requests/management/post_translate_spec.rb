# frozen_string_literal: true

require 'rails_helper'

# The sibling of update that spends money: it has to be as closed as the screen it serves.
describe 'POST /management/posts/translate', type: :request do
  let(:path) { translate_management_posts_path(locale: 'en') }
  let(:params) { { input_data: '<p>Hello</p>' } }

  before { allow(ChatgptService).to receive(:call).and_return('<p>Привіт</p>') }

  it 'refuses a visitor who is not signed in, without calling the service' do
    post(path, params:)

    expect(response).to redirect_to(new_user_session_path)
    expect(ChatgptService).not_to have_received(:call)
  end

  %i[moderator user].each do |role|
    it "refuses a #{role}, without calling the service" do
      sign_in(create(:user, role:))

      post(path, params:)

      expect(response).to redirect_to(root_path)
      expect(ChatgptService).not_to have_received(:call)
    end
  end

  context 'when an admin asks' do
    before { sign_in(create(:user, role: :admin)) }

    it 'answers with the translation' do
      post(path, params:)

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to eq('data' => '<p>Привіт</p>')
      expect(ChatgptService).to have_received(:call)
        .with(satisfy { |sent| sent[:input_data] == '<p>Hello</p>' && sent[:locale] == 'en' })
    end

    it 'answers 502 when the service gives up, not a 500' do
      allow(ChatgptService).to receive(:call).and_raise(ChatgptService::Error, 'upstream is down')

      post(path, params:)

      expect(response).to have_http_status(:bad_gateway)
      expect(response.parsed_body['error']).to be_present
    end
  end
end
