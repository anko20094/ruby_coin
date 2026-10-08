# frozen_string_literal: true

require 'rails_helper'

describe EditorHelper do
  describe '#editor_html' do
    let(:post) { create(:post) }

    it 'returns an empty string rather than raising on a body that does not exist' do
      expect(helper.editor_html(nil)).to eq('')
    end

    it 'hands plain prose straight through' do
      post.update!(description_en: '<p>one</p><p>two</p>')

      expect(helper.editor_html(post.rich_text_description_en)).to eq('<p>one</p><p>two</p>')
    end

    context 'with an uploaded image in the body' do
      let(:dot) { Base64.decode64(<<~PNG) }
        iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==
      PNG
      let(:blob) do
        ActiveStorage::Blob.create_and_upload!(io: StringIO.new(dot), filename: 'dot.png', content_type: 'image/png')
      end
      let(:html) { helper.editor_html(post.rich_text_description_en) }

      before do
        attachment = %(<action-text-attachment sgid="#{blob.attachable_sgid}" content-type="image/png">) \
                     '</action-text-attachment>'
        post.update!(description_en: "<p>before</p>#{attachment}")
      end

      after { blob.purge }

      it 'fills the attachment with the figure the public page draws' do
        expect(html).to include('<figure class="attachment attachment--preview attachment--png">')
        expect(html).to match(/<action-text-attachment[^>]+contenteditable="false"/)
      end

      it 'draws it once, not as an element holding an empty copy of itself' do
        expect(html.scan('<action-text-attachment').size).to eq(1)
      end
    end

    context 'with a journal block in the body' do
      let(:block) { JournalBlock.create!(kind: 'code', payload: { 'language' => 'ruby', 'source' => 'puts 1' }) }

      before do
        attachment = %(<action-text-attachment sgid="#{block.attachable_sgid}"></action-text-attachment>)
        post.update!(description_en: "<p>before</p>#{attachment}")
      end

      # Stored, an attachment is an empty element — the block lives in its own row and is
      # re-rendered on every page view. An empty element is an invisible hole in a WYSIWYG
      # editor, which is the whole reason this helper exists.
      it 'fills the attachment with the partial the public page renders' do
        html = helper.editor_html(post.rich_text_description_en)

        expect(html).to include('<p>before</p>')
        expect(html).to include('puts')
        expect(html).to match(/<action-text-attachment[^>]+contenteditable="false"/)
      end

      # The load-bearing assumption. If Action Text ever stopped discarding an attachment's
      # children, every save would store a stale copy of the rendered block beside the sgid.
      it 'does not store what it filled in, because Action Text drops it again on save' do
        post.update!(description_en: helper.editor_html(post.rich_text_description_en))

        stored = post.reload.rich_text_description_en.body.to_html
        expect(stored).to include(block.attachable_sgid)
        expect(stored).not_to include('puts')
        expect(stored).to match(%r{<action-text-attachment[^>]*></action-text-attachment>})
      end
    end
  end
end
