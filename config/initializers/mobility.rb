# frozen_string_literal: true

# Mobility replaces Globalize as the translation layer for Post.
#
# The Table backend's defaults already match the schema Globalize left behind: table
# post_translations, foreign key post_id, association Post#translations. So the swap needed no
# options and no data migration — see redesign_plan.md §4.2, which is why this was the low-risk
# route rather than moving the data to JSONB in the same step.
#
# Two plugins are deliberately left off:
#
#   fallbacks — Globalize had none, and the site relies on that. A post with no English title
#              renders an empty title, which is the signal the admin's language-pair indicator
#              is meant to surface. Turning fallbacks on would hide missing translations.
#   dirty     — nothing asks Post whether a translation changed.
Mobility.configure do
  plugins do
    backend :table

    active_record

    reader
    writer
    backend_reader

    # Post.i18n, for querying on translated attributes.
    query

    cache

    # Blank strings become nil on read and write. Globalize stored them as given; nothing in
    # the app distinguishes "" from nil, and the presence validations treat them the same.
    presence
  end
end
