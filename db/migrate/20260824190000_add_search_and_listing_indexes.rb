# frozen_string_literal: true

# Two query shapes the site runs on every page load had nothing behind them.
#
# 1. The journal list, the home page and the admin list all end in
#    `WHERE status = 0 ORDER BY created_at DESC` — a sequential scan plus a sort, and one that
#    gets slower with every entry published.
# 2. post_translations holds one row per (post, locale) by construction but nothing enforced
#    it, so a bug could quietly create a second and the app would read whichever came first.
#    The standalone index on `locale` cannot help any query — the column has two values across
#    the whole table.
#
# Not here, deliberately: a GIN index for search. pg_search builds its WHERE clause as
# `to_tsvector(body_en) || to_tsvector(body_uk) || to_tsvector(titles) @@ query`, and a
# concatenation of tsvectors cannot be served by an index on any one of them — verified with
# EXPLAIN and enable_seqscan off, which still refused the index. Making search indexable means
# a stored tsvector column, which in turn means mirroring the titles out of post_translations
# onto posts. That is a real change with a real sync-bug surface, and at this size search is
# milliseconds; it is written down in redesign_plan.md rather than half-done here.
class AddSearchAndListingIndexes < ActiveRecord::Migration[8.1]
  def change
    reversible { |direction| direction.up { refuse_duplicate_translations } }

    add_index :posts, %i[status created_at]

    remove_index :post_translations, :locale
    add_index :post_translations, %i[post_id locale], unique: true
  end

  private

  # Never deleted for the operator: the row that loses may be the only holder of a legacy body.
  def refuse_duplicate_translations
    duplicates = select_rows(<<~SQL.squish)
      SELECT post_id, locale, count(*) FROM post_translations
      GROUP BY post_id, locale HAVING count(*) > 1 ORDER BY post_id, locale
    SQL
    return if duplicates.empty?

    pairs = duplicates.map { |post_id, locale, count| "#{post_id}/#{locale} (#{count} rows)" }.join(', ')
    raise ActiveRecord::MigrationError, "post_translations holds more than one row for post/locale #{pairs}; " \
                                        'merge each pair by hand, keeping the one with the description'
  end
end
