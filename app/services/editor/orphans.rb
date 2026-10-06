# frozen_string_literal: true

class Editor::Orphans < BaseService
  Result = Struct.new(:blocks, :blobs, keyword_init: true)

  # A blob URL in a body: /rails/active_storage/{blobs,representations}/[redirect|proxy/]<signed id>/…
  BLOB_URL = %r{/rails/active_storage/(?:blobs|representations)/(?:redirect/|proxy/)?([^/"'\s?]+)/}

  def initialize(older_than: 7.days, delete: false)
    @cutoff = older_than.ago
    @delete = delete
  end

  def call
    block_ids, blob_ids = referenced
    blocks = JournalBlock.where(created_at: ...@cutoff).where.not(id: block_ids)
    blobs = ActiveStorage::Blob.unattached.where(created_at: ...@cutoff).where.not(id: blob_ids)
    result = Result.new(blocks: blocks.ids, blobs: blobs.ids)

    if @delete
      blocks.delete_all
      blobs.find_each(&:purge)
    end

    result
  end

  private

  # Every journal block and blob any stored text points at.
  def referenced
    block_ids = Set.new
    blob_ids = Set.new

    ActionText::RichText.find_each do |rich_text|
      content = rich_text.body
      next if content.blank?

      content.fragment.find_all(ActionText::Attachment.tag_name).each { |node| block_ids << block_id(node['sgid']) }
      blob_ids.merge(blob_ids_in(content.to_html))
    end
    # Case fields are TinyMCE markup as well; an image URL there is a reference too.
    Case.find_each { |kase| blob_ids.merge(blob_ids_in(kase.attributes.to_json)) }

    [block_ids.compact.to_a, blob_ids.compact.to_a]
  end

  def block_id(sgid)
    global_id = SignedGlobalID.parse(sgid, for: ActionText::Attachable::LOCATOR_NAME)
    global_id.model_id.to_i if global_id&.model_name == JournalBlock.name
  end

  def blob_ids_in(text)
    text.to_s.scan(BLOB_URL).flatten.uniq.filter_map { |signed_id| ActiveStorage::Blob.find_signed(signed_id)&.id }
  end
end
