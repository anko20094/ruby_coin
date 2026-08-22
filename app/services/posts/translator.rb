# frozen_string_literal: true

class Posts::Translator < BaseService
  attr_accessor :post, :params

  def initialize(post, params)
    @post = post
    @params = params
  end

  def call
    return false unless localization_valid?(params)

    I18n.available_locales.each do |locale|
      article = post.post_translations.find_or_create_by(locale:)

      update_post(article, locale)
    end
  end

  private

  def update_post(article, locale)
    if params.dig('title_localizations', locale).present?
      article.update!(title: params.dig('title_localizations', locale))
    end

    if params.dig('subtitle_localizations', locale).present?
      article.update(subtitle: params.dig('subtitle_localizations', locale))
    end
  end

  def localization_valid?(localization_params)
    localization_params.each do |field, translations|
      translations.each_value do |value|
        next if value.present?

        fieldname = field.delete_suffix('_localizations')
        message = I18n.t("activerecord.errors.models.post.attributes.#{fieldname}.translation_missing")

        @post.errors.add(fieldname.to_sym, message:)
      end
    end

    @post.errors.blank?
  end
end
