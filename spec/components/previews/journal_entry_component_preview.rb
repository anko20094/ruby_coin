# frozen_string_literal: true

class JournalEntryComponentPreview < ViewComponent::Preview
  # A row in the middle of the list.
  def default
    render(JournalEntryComponent.new(post: sample_post))
  end

  # The first row also carries the strong hairline that opens the list.
  def first_row
    render(JournalEntryComponent.new(post: sample_post, first: true))
  end

  # Anything published inside Post::RECENT_FOR wears the ruby NEW badge.
  def recent
    render(JournalEntryComponent.new(post: sample_post(created_at: Time.current), first: true))
  end

  private

  # Previews must not write to the database, so this is an unsaved post with just enough
  # on it for the row to render.
  def sample_post(created_at: 6.months.ago)
    Post.new(
      title: 'Rebuilt the pipeline on Propshaft',
      slug: 'rebuilt-the-pipeline-on-propshaft',
      entry_number: 42,
      created_at: created_at,
      user: User.new(nickname: 'danyil'),
      description_en: "<p>#{'word ' * 900}</p>"
    )
  end
end
