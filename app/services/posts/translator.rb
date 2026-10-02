# frozen_string_literal: true

# Puts the editor's other-language title and subtitle on the post through Mobility's locale
# accessors, so they are written by the same save as the rest of the post. It only assigns:
# the caller saves, and a refused value is a validation error on that save rather than a
# second write that can fail on its own.
class Posts::Translator < BaseService
  FIELDS = %w[title subtitle].freeze

  attr_reader :post, :params

  def initialize(post, params)
    @post = post
    @params = params
  end

  # False when a submitted language is blank; the post then carries its own validation errors
  # and the missing translations together, so the form shows all of them at once.
  def call
    missing = assign
    return true if missing.empty?

    post.validate
    missing.each do |field|
      message = I18n.t("activerecord.errors.models.post.attributes.#{field}.translation_missing")
      post.errors.add(field.to_sym, message:)
    end
    false
  end

  private

  def assign
    FIELDS.each_with_object([]) do |field, missing|
      params.fetch("#{field}_localizations") { {} }.each do |locale, value|
        next unless I18n.available_locales.include?(locale.to_sym)
        next missing << field if value.blank?

        post.public_send(:"#{field}_#{locale}=", value)
      end
    end
  end
end
