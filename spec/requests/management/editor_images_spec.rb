# frozen_string_literal: true

require 'rails_helper'

# TinyMCE's image button uploads here and expects one thing back — `location` — which it writes
# into the <img src> it inserts. An upload endpoint any signed-in user can reach is a place to
# park files, so what it refuses matters as much as what it accepts.
describe 'Management::EditorImages' do
  let(:png) { Rack::Test::UploadedFile.new('spec/fixtures/files/pixel.png', 'image/png') }

  it 'refuses an anonymous upload' do
    post '/en/management/editor_images', params: { file: png }

    expect(response).to have_http_status(:found)
    expect(response.location).to include('users/sign_in')
    expect(ActiveStorage::Blob.count).to eq(0)
  end

  it 'refuses a signed-in reader who is not an admin' do
    sign_in create(:user, role: :user)

    expect { post '/en/management/editor_images', params: { file: png } }
      .not_to change(ActiveStorage::Blob, :count)
  end

  context 'when the uploader is an admin' do
    before { sign_in create(:user, role: :admin) }

    # Two blobs, not one: the upload, and the variant Active Storage stores beside it.
    it 'stores the upload and answers with the URL TinyMCE asks for' do
      expect { post '/en/management/editor_images', params: { file: png } }
        .to change(ActiveStorage::VariantRecord, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body['location']).to be_present
    end

    # A phone camera hands over 2208×2944 and the measure it lands in is 760px wide. Serving
    # the original means every reader downloads several megabytes to look at something 760px
    # across; the original stays in storage, the body gets a variant.
    it 'points the body at a bounded variant, not at the original' do
      post '/en/management/editor_images', params: { file: png }

      expect(response.parsed_body['location']).to include('representations')
    end

    # A variant of an SVG is not a thing, and a variant of a GIF is its first frame.
    it 'serves an SVG as it arrived' do
      svg = Rack::Test::UploadedFile.new(StringIO.new('<svg xmlns="http://www.w3.org/2000/svg"/>'),
                                         'image/svg+xml', original_filename: 'mark.svg')

      post '/en/management/editor_images', params: { file: svg }

      expect(response).to have_http_status(:created)
      expect(response.parsed_body['location']).to include('blobs')
      expect(response.parsed_body['location']).not_to include('representations')
    end

    it 'refuses a file that is not an image before anything touches disk' do
      text = Rack::Test::UploadedFile.new('spec/fixtures/files/pixel.png', 'text/html')

      expect { post '/en/management/editor_images', params: { file: text } }
        .not_to change(ActiveStorage::Blob, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['error']).to be_present
    end

    it 'refuses an image over the size limit' do
      allow_any_instance_of(ActionDispatch::Http::UploadedFile)
        .to receive(:size).and_return(Management::EditorImagesController::MAX_BYTES + 1)

      expect { post '/en/management/editor_images', params: { file: png } }
        .not_to change(ActiveStorage::Blob, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'refuses a request with no file at all' do
      post '/en/management/editor_images'

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
