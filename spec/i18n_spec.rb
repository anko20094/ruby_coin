# frozen_string_literal: true

require 'rails_helper'

describe 'the locale files' do # rubocop:disable RSpec/DescribeClass
  let(:files) { Rails.root.glob('config/locales/*.yml') }
  let(:plural_categories) { %w[zero one two few many other] }
  let(:forms_needed) { { uk: %w[one few many other], en: %w[one other] } }
  let(:tables) do
    I18n.available_locales.index_with do |locale|
      files.filter_map { |file| YAML.load_file(file, aliases: true)[locale.to_s] }.reduce({}, :deep_merge)
    end
  end
  let(:leaves) { tables.transform_values { |table| leaves_of(table) } }
  let(:all_keys) { leaves.values.flat_map(&:keys).uniq }

  def plural?(node)
    node.is_a?(Hash) && node.any? && node.keys.all? { |key| plural_categories.include?(key.to_s) }
  end

  def leaves_of(node, path = [])
    return { path.join('.') => node } unless node.is_a?(Hash) && !plural?(node)

    node.reduce({}) { |found, (key, value)| found.merge(leaves_of(value, [*path, key])) }
  end

  def duplicate_keys(node, path = [])
    case node
    when Psych::Nodes::Mapping
      pairs = node.children.each_slice(2).to_a
      repeated = pairs.map { |key, _| key.value }.tally.select { |_, count| count > 1 }.keys
      repeated.map { |name| [*path, name].join('.') } +
        pairs.flat_map { |key, value| duplicate_keys(value, [*path, key.value]) }
    when Psych::Nodes::Sequence, Psych::Nodes::Document
      node.children.flat_map { |child| duplicate_keys(child, path) }
    else
      []
    end
  end

  def variables_in(value)
    text = value.is_a?(Hash) ? value.values.join(' ') : Array(value).join(' ')
    text.scan(/%\{(\w+)\}/).flatten.uniq.sort
  end

  it 'defines no key twice in one mapping, which YAML resolves by dropping the first' do
    repeated = files.to_h { |file| [file.basename.to_s, duplicate_keys(Psych.parse_file(file))] }

    expect(repeated.reject { |_, keys| keys.empty? }).to be_empty
  end

  it 'defines every key in every locale' do
    gaps = leaves.transform_values { |table| all_keys - table.keys }

    expect(gaps.reject { |_, keys| keys.empty? }).to be_empty
  end

  it 'interpolates the same variables in every locale' do
    mismatched = all_keys.filter_map do |key|
      used = leaves.transform_values { |table| variables_in(table[key]) }
      [key, used] if used.values.uniq.size > 1
    end

    expect(mismatched).to be_empty
  end

  it 'gives every count the plural forms its language needs' do
    incomplete = forms_needed.to_h do |locale, forms|
      counted = leaves[locale].select { |_, value| value.is_a?(Hash) }
      [locale, counted.select { |_, value| (forms - value.keys.map(&:to_s)).any? }.keys]
    end

    expect(incomplete.reject { |_, keys| keys.empty? }).to be_empty
  end

  it 'raises on a missing translation in the test environment' do
    expect(Rails.application.config.i18n.raise_on_missing_translations).to be(true)
  end

  describe 'a rejected upload' do
    def rejection(content, name)
      Tempfile.create([File.basename(name, '.*'), File.extname(name)]) do |file|
        file.write(content)
        file.flush
        PhotoUploader.new(Post.new, :photo).cache!(File.open(file.path))
      end
      nil
    rescue CarrierWave::IntegrityError => e
      e.message
    end

    %i[uk en].each do |locale|
      context "when the admin reads #{locale}" do
        around { |example| I18n.with_locale(locale, &example) }

        it 'says a file that is not an image is not an image' do
          message = rejection('<?php echo 1; ?>', 'payload.png')

          expect(message).to be_present
          expect(message).not_to match(/translation missing|\(\?-mix/i)
        end

        it 'says how large a cover may be' do
          message = rejection("GIF89a#{'0' * 9.megabytes}", 'cover.gif')

          expect(message).to be_present
          expect(message).not_to match(/translation missing/i)
        end

        it 'says an empty file is no cover' do
          message = rejection('', 'cover.png')

          expect(message).to be_present
          expect(message).not_to match(/translation missing|\(\?-mix/i)
        end
      end
    end

    it 'keeps the validators fallbacks CarrierWave looks up by their own names' do
      keys = %w[carrierwave_processing_error carrierwave_integrity_error carrierwave_download_error]

      I18n.available_locales.each do |locale|
        keys.each { |key| expect(I18n.exists?("errors.messages.#{key}", locale)).to be(true), "#{locale}: #{key}" }
      end
    end
  end

  describe 'the admin chrome', type: :request do
    let(:post_record) { create(:post) }
    let(:widths) { %w[desktop mobile] }

    before { sign_in create(:user, role: :admin) }

    def labelled(name, locale)
      I18n.t("management.posts.editor.width.#{name}", locale: locale)
    end

    %i[uk en].each do |locale|
      it "names the preview widths in #{locale}" do
        get "/#{locale}/management/posts/#{post_record.id}/edit"

        buttons = response.parsed_body.css('.mg-preview__width').map { |button| button.text.strip }
        expect(buttons).to eq(widths.map { |name| labelled(name, locale) })
      end

      it "writes the breadcrumb of every screen in #{locale}" do
        screens = { posts: 'posts', cases: 'cases', tags: 'tags', statistics: 'statistics' }

        crumbs = screens.to_h do |name, path|
          get "/#{locale}/management/#{path}"
          [name, response.parsed_body.at_css('.mg-crumbs__here')&.text]
        end

        expect(crumbs).to eq(screens.keys.index_with { |name| I18n.t("management.crumbs.#{name}", locale: locale) })
      end
    end

    it 'hands the editor a name for each block format, in the reader\'s language' do
      get "/uk/management/posts/#{post_record.id}/edit"

      labels = JSON.parse(CGI.unescapeHTML(response.body[/data-tinymce-labels-value="([^"]+)"/, 1]))
      keys = %w[paragraph heading2 heading3 heading4 preformatted]

      expect(labels.values_at(*keys)).to all(be_present)
      expect(labels.values_at(*keys)).to eq(keys.map { |key| I18n.t("management.editor.tinymce.#{key}", locale: :uk) })
    end
  end
end
