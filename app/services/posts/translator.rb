# frozen_string_literal: true

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
