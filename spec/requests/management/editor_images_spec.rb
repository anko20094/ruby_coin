# frozen_string_literal: true

require 'rails_helper'

# TinyMCE's image button uploads here and expects one thing back — `location` — which it writes
# into the <img src> it inserts. An upload endpoint any signed-in user can reach is a place to
# park files, so what it refuses matters as much as what it accepts.
describe 'Management::EditorImages' do
  let(:png) { Rack::Test::UploadedFile.new('spec/fixtures/files/pixel.png', 'image/png') }
  let(:path) { '/en/management/editor_images' }

  let(:scratch) { Pathname(Dir.mktmpdir('editor-images', Rails.root.join('tmp'))) }

  after { FileUtils.rm_rf(scratch) }

  def upload(content, type, name)
    Rack::Test::UploadedFile.new(StringIO.new(content), type, original_filename: name)
  end

  def phone_photo(orientation: 6)
    source = ImageFixtures.jpeg_with_exif(scratch.join('phone.jpg'), width: 3000, height: 2000,
                                                                     orientation: orientation)
    Rack::Test::UploadedFile.new(source, 'image/jpeg')
  end

  def exposed?(bytes) = bytes.include?(ImageFixtures::CAMERA_MAKE)

  def dimensions(bytes)
    scratch.join('served').binwrite(bytes)
    MiniMagick::Image.new(scratch.join('served').to_s).dimensions
  end

  it 'refuses an anonymous upload' do
    post path, params: { file: png }

    expect(response).to have_http_status(:found)
    expect(response.location).to include('users/sign_in')
    expect(ActiveStorage::Blob.count).to eq(0)
  end

  it 'refuses a signed-in reader who is not an admin' do
    sign_in create(:user, role: :user)

    expect { post path, params: { file: png } }
      .not_to change(ActiveStorage::Blob, :count)
  end

  context 'when the uploader is an admin' do
    before { sign_in create(:user, role: :admin) }

    it 'stores the upload and answers with the URL TinyMCE asks for' do
      expect { post path, params: { file: png } }.to change(ActiveStorage::Blob, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body['location']).to start_with('/rails/active_storage/blobs/redirect/')
    end

    # The blob is the thing a signed URL serves, and the signed id in the body's <img> is
    # enough to ask for it; whatever is not stripped from it is public.
    context 'with a phone photo' do
      before { post path, params: { file: phone_photo } }

      let(:location) { response.parsed_body['location'] }

      it 'stores one blob, upright, bounded and without the camera or the GPS position' do
        blob = ActiveStorage::Blob.sole

        expect(response).to have_http_status(:created)
        expect(blob.content_type).to eq('image/jpeg')
        expect(exposed?(blob.download)).to be(false)
        expect(blob.download).not_to include('Exif')
        expect(dimensions(blob.download)).to eq([1067, 1600])
      end

      it 'serves clean bytes from the URL it hands back and from every other URL for the same file' do
        urls = [location, *ActiveStorage::Blob.all.map { |blob| rails_blob_path(blob, only_path: true) }]

        urls.each do |url|
          get url
          follow_redirect!

          expect(response).to have_http_status(:ok)
          expect(exposed?(response.body)).to be(false)
          expect(dimensions(response.body)).to eq([1067, 1600])
        end
      end
    end

    it 'keeps a small image at its own size' do
      post path, params: { file: png }

      expect(dimensions(ActiveStorage::Blob.last.download)).to eq([1, 1])
    end

    it 'trusts the bytes over the header and names the file for what it is' do
      lying = Rack::Test::UploadedFile.new(ImageFixtures.plain_image(scratch.join('shot.jpg'), width: 40, height: 30),
                                           'text/plain', original_filename: 'holiday.png')

      post path, params: { file: lying }

      blob = ActiveStorage::Blob.last
      expect(response).to have_http_status(:created)
      expect([blob.content_type, blob.filename.to_s]).to eq(['image/jpeg', 'holiday.jpg'])
    end

    it 'keeps every frame of a GIF and does not resize it' do
      gif = Rack::Test::UploadedFile.new(ImageFixtures.animated_gif(scratch.join('loop.gif')), 'image/gif')

      post path, params: { file: gif }

      scratch.join('stored.gif').binwrite(ActiveStorage::Blob.last.download)
      stored = MiniMagick::Image.new(scratch.join('stored.gif').to_s)
      expect([stored.type, stored.layers.size, stored.dimensions]).to eq(['GIF', 3, [200, 150]])
    end

    it 'refuses an SVG, which Active Storage would serve as a download' do
      svg = upload('<svg xmlns="http://www.w3.org/2000/svg"/>', 'image/svg+xml', 'mark.svg')

      expect { post path, params: { file: svg } }.not_to change(ActiveStorage::Blob, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['error']).to eq(I18n.t('management.editor_images.create.type', locale: :en))
    end

    it 'refuses a script that says it is a PNG, and a page that says it is a JPEG' do
      mvg = upload("push graphic-context\nfill red\npop graphic-context\n", 'image/png', 'evil.mvg')
      html = upload('<!doctype html><script>alert(1)</script>', 'image/jpeg', 'page.jpg')

      [mvg, html].each do |file|
        expect { post path, params: { file: file } }.not_to change(ActiveStorage::Blob, :count)
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body['error']).to eq(I18n.t('management.editor_images.create.type', locale: :en))
      end
    end

    it 'refuses an image the processor cannot read, instead of storing it untouched' do
      corrupt = upload("\xFF\xD8\xFF\xE0".b + ('garbage' * 200), 'image/jpeg', 'broken.jpg')

      expect { post path, params: { file: corrupt } }.not_to change(ActiveStorage::Blob, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['error']).to eq(I18n.t('management.editor_images.create.processing', locale: :en))
    end

    it 'refuses an image over the size limit before reading it' do
      stub_const('Management::EditorImagesController::MAX_BYTES', 1.megabyte)
      noise = Dir::Tmpname.create(['noise', '.png'], Rails.root.join('tmp')) { |path| path }
      MiniMagick.convert { |convert| convert.size('1500x1500') << 'plasma:fractal' << noise }
      big = upload(File.binread(noise), 'image/png', 'big.png')
      FileUtils.rm_f(noise)

      expect { post path, params: { file: big } }.not_to change(ActiveStorage::Blob, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['error']).to eq(I18n.t('management.editor_images.create.size', limit: 1, locale: :en))
    end

    it 'refuses a request with no file at all' do
      post path

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
