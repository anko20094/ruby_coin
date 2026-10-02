# frozen_string_literal: true

# /faq is restyled onto the new theme but stays out of the nav (docs/decisions.md).
class FaqController < ApplicationController
  def index
    @entries = faq_entries

    # The copy is in the locale files, which are part of the release.
    cache_publicly
  end

  private

  # The copy lives in the locale files, one section per question, and the view walks it rather
  # than repeating the same markup six times. A key named question* is the question; everything
  # else in the section is an answer paragraph, in file order. Keys ending in _html carry a
  # link and are rendered as markup.
  def faq_entries
    I18n.t('faq').filter_map do |_section, entry|
      next unless entry.is_a?(Hash)

      question = entry.find { |key, _| key.to_s.start_with?('question') }
      next if question.nil?

      {
        question: question.last,
        answers: entry.except(question.first).map { |key, text| { markup: key.to_s.end_with?('_html'), text: text } }
      }
    end
  end
end
