# frozen_string_literal: true

# What a fresh checkout needs to look like the site: the real portfolio content, a way in,
# and enough journal entries that the index, the pager and the tag filter have something to
# do.
#
# Outside development and test it creates the admin and nothing else, because the deploy owns
# the portfolio. ALLOW_SEED opens it to such an environment; SEED_ADMIN_EMAIL and
# SEED_ADMIN_PASSWORD are then required.
#
# Idempotent: run it twice and nothing doubles.

return unless Rails.env.local? || ENV['ALLOW_SEED'].present?

def say(message) = puts("  #{message}")

puts "\nseeding #{Rails.env}"

# --- a way in -----------------------------------------------------------------------------
email = ENV['SEED_ADMIN_EMAIL'].presence
password = ENV['SEED_ADMIN_PASSWORD'].presence
if !Rails.env.local? && (email.nil? || password.nil?)
  abort '  SEED_ADMIN_EMAIL and SEED_ADMIN_PASSWORD are required outside development and test.'
end

admin = User.find_or_initialize_by(email: email || 'admin@rubyco.in')
if admin.new_record?
  admin.password = password || SecureRandom.base64(12)
  admin.nickname = ENV['SEED_ADMIN_NICKNAME'].presence || 'danyil'
  admin.role = :admin
  admin.save!
  say "password: #{admin.password}" if password.nil?
end
say "admin: #{admin.email}"

return unless Rails.env.local?

# --- the portfolio ------------------------------------------------------------------------
# Cases are real content, never retyped by hand: the same importer the deploy runs loads them
# from cases.yml. The CV is read from cv.yml as it is.
import = Cases::Importer.call
abort "  the cases do not match their yaml:\n    #{import.mismatches.join("\n    ")}" unless import.ok?
say "cases: #{Case.count} · profile: #{Team.owner_cv.name}"

# --- the journal --------------------------------------------------------------------------
TAGS = %w[rails hotwire postgres activerecord viewcomponent turbo].freeze
tags = TAGS.map { |title| Tag.find_or_create_by!(title: title) }

ENTRIES = [
  [
    'Solid Queue, and one less service in the deploy',
    'Solid Queue і на один сервіс менше в деплої'
  ],
  [
    'Mobility on the table Globalize left behind',
    'Mobility на таблиці, яку лишив Globalize'
  ],
  [
    'Action Text is a storage decision, not an editor',
    'Action Text — це рішення про сховище, а не редактор'
  ],
  [
    'ViewComponent earns its keep at the third caller',
    'ViewComponent окупається на третьому виклику'
  ],
  [
    'pg_search and the join you should not make',
    'pg_search і джойн, якого краще не робити'
  ],
  [
    'A slug history is cheaper than a redirect table',
    'Історія слагів дешевша за таблицю редиректів'
  ],
  [
    'Counting views without counting yourself',
    'Рахувати перегляди, не рахуючи себе'
  ],
  [
    'Self-hosting four faces and cutting the subsets',
    'Самохостинг чотирьох шрифтів і різання сабсетів'
  ]
].freeze

# One more page than the journal shows at once, and two entries on it, so the pager has a second
# page to go to and a last page that is not a single row.
numbers = (ENTRIES.size + 1)..(JournalController::PER_PAGE + 2)
filler = numbers.map { |number| [format('Seeded entry %02d', number), format('Засіяний запис %02d', number)] }
SEEDED = (ENTRIES + filler).freeze

BODY = {
  en: '<p>A short entry, seeded so the journal has shape: an index with more than one page, ' \
      'a tag filter with something to filter, and a post long enough to read.</p>' \
      '<p>Replace it from /management as soon as there is something real to say — the ' \
      'editorial rule on this site is that silence beats filler.</p>',
  uk: '<p>Короткий запис, засіяний, щоб журнал мав форму: індекс більш ніж на одну сторінку, ' \
      'фільтр тегів, якому є що фільтрувати, і пост, який можна прочитати.</p>' \
      '<p>Заміни його з /management, щойно буде що сказати насправді — редакційне правило ' \
      'цього сайту таке, що краще тиша, ніж філер.</p>'
}.freeze

LEDE = {
  en: 'Seeded copy. Not something I actually wrote.',
  uk: 'Засіяний текст. Це не те, що я справді писав.'
}.freeze

cover = Rails.root.join('db/seeds/files/work-portrait.jpg') # rubocop:disable Rails/FilePath

# Every post needs a cover and covers go through ImageMagick, so ask it to read one image up
# front rather than finding out nine rows in. This replaces a `rescue CarrierWave::Processing\
# Error` around `save!` that could never fire: CarrierWave turns a processing failure into a
# validation error on :photo, so what actually reached it was ActiveRecord::RecordInvalid and
# the friendly message below never printed.
#
# #validate! rather than #open, because MiniMagick 5's #open only copies bytes into a tempfile
# — #validate! is what runs `magick identify`. And MiniMagick::Invalid is not a
# MiniMagick::Error, the gem hangs it straight off StandardError, so both have to be named.
begin
  MiniMagick::Image.open(cover.to_s).validate!
rescue MiniMagick::Invalid, MiniMagick::Error, Errno::ENOENT => e
  # #squish because the reason a broken install gives — "cannot open shared object file" —
  # is on the second line of what MiniMagick raises.
  abort "  ImageMagick cannot read #{cover.basename}: #{e.message.squish}\n  " \
        'Install ImageMagick and re-run.'
end

created = 0
SEEDED.each_with_index do |(en_title, uk_title), index|
  slug = en_title.parameterize
  next if Post.exists?(slug: slug)

  post = Post.new(user: admin, status: :active, main_post: index.zero?, slug: slug,
                  created_at: (index * 9).days.ago, tags: tags.sample(3))
  I18n.with_locale(:en) do
    post.title = en_title
    post.subtitle = LEDE[:en]
  end
  I18n.with_locale(:uk) do
    post.title = uk_title
    post.subtitle = LEDE[:uk]
  end
  post.description_en = BODY[:en]
  post.description_uk = BODY[:uk]
  post.photo = File.open(cover)

  post.save!
  created += 1
end

# A post seeded before the uploader was rewritten still carries the old versions on disk —
# `medium_cover.png` where PhotoUploader now asks for `medium_cover.jpg`. The row looks fine
# and the file the column names is there, so nothing notices until a cover renders as a
# broken image. Re-attaching the source rebuilds the versions under the names in force now.
repaired = 0
Post.where(slug: SEEDED.map { |en, _uk| en.parameterize }).find_each do |post|
  next if post.photo.blank?
  next if File.exist?(post.photo.medium.path.to_s)

  post.photo = File.open(cover)
  post.save!
  repaired += 1
end

say "journal: #{created} new, #{repaired} covers rebuilt, #{Post.count} total"
puts "done\n\n"
