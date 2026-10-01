# frozen_string_literal: true

shared_examples 'redirects to new_user_session_path' do |verb = :get|
  it 'redirects to new_user_session_path' do
    public_send(verb, action, params:)
    expect(response).to redirect_to(new_user_session_path)
  end
end

shared_examples 'has http success' do |verb = :get|
  it 'responds with success' do
    public_send(verb, action, params:)
    expect(response).to have_http_status(:success)
  end
end

shared_examples 'unprocessable_entity status' do |verb = :get|
  it 'responds with unprocessable_entity status' do
    public_send(verb, action, params:)
    expect(response).to have_http_status(:unprocessable_content)
  end
end
