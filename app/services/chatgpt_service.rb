# frozen_string_literal: true

class ChatgptService < BaseService
  include HTTParty

  class Error < StandardError; end

  DEFAULT_MODEL = 'gpt-5.4'
  LANGUAGE = { uk: 'Ukrainian', en: 'English' }.freeze

  SECTION_HEADINGS = %w[h1 h2 h3].freeze
  SECTION_LIMIT = 16_384
  SPLIT_AT = 90_000

  # One section is up to 16 KB of HTML and comes back as a completion of about that size.
  TIMEOUT = 120
  MAX_PARALLEL = 4
  NETWORK_ERRORS = [
    Timeout::Error, SocketError, SystemCallError, EOFError, OpenSSL::SSL::SSLError, JSON::ParserError,
    HTTParty::Error
  ].freeze

  attr_reader :api_url, :options, :model, :message, :locale

  def initialize(params, model = DEFAULT_MODEL)
    gpt_key = Rails.application.credentials.chat_gpt_key
    @options = {
      headers: {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{gpt_key}"
      }
    }
    @api_url = 'https://api.openai.com/v1/chat/completions'
    @model = model
    @message = params[:input_data]
    @locale = params[:locale]
  end

  def call
    raise Error, 'nothing to translate' if message.blank?

    choose_translation_language(locale)

    return translate(message) unless message.length > SPLIT_AT

    translated = separated_content(message).each_slice(MAX_PARALLEL).flat_map do |sections|
      sections.map { |section| Thread.new { translate(section) } }.map(&:value)
    end

    translated.join
  end

  private

  def translate(section)
    body = {
      model:,
      messages: [
        {
          role: 'system',
          content: 'You are now using the ChatGPT API to translate the provided HTML content ' \
                   "from #{@input_locale} into #{@output_locale} while preserving its structure."
        },
        {
          role: 'user',
          content: section
        },
        {
          role: 'assistant',
          content: "Translate the provided HTML content from #{@input_locale} into " \
                   "#{@output_locale} while preserving its structure."
        }
      ]
    }

    response = HTTParty.post(api_url, body: body.to_json, headers: options[:headers], timeout: TIMEOUT)
    raise Error, failure_message(response) unless response.code == 200

    completion(response.parsed_response)
  rescue *NETWORK_ERRORS => e
    raise Error, e.message
  end

  def failure_message(response)
    parsed = response.parsed_response
    detail = parsed.dig('error', 'message') if parsed.is_a?(Hash)

    detail.presence || "OpenAI answered #{response.code}"
  end

  # Only a completion the model finished is a translation; a refusal or a cut-off answer would
  # otherwise be stored as the article.
  def completion(parsed)
    choice = parsed.is_a?(Hash) ? parsed.dig('choices', 0) : nil
    finish = choice&.dig('finish_reason')
    content = choice&.dig('message', 'content')

    raise Error, "translation stopped early (#{finish.inspect})" unless finish == 'stop'
    raise Error, 'translation came back empty' if content.blank?

    content
  end

  def choose_translation_language(locale)
    @input_locale = LANGUAGE[locale.to_sym]

    @output_locale = locale == 'en' ? LANGUAGE[:uk] : LANGUAGE[:en]
  end

  def separated_content(message)
    doc = Nokogiri::HTML(message)

    sections = divide_by_tags(doc)

    unite_by_tokens(sections)
  end

  # A section opens at every h1–h3 and runs to the next one; whatever comes before the first
  # heading is a section of its own, and deeper headings stay inside the section they sit in.
  def divide_by_tags(doc)
    nodes = doc.at('body')&.children.to_a
    groups = nodes.slice_before { |node| node.element? && SECTION_HEADINGS.include?(node.name) }

    groups.map { |group| group.map(&:to_html).join }.compact_blank
  end

  def unite_by_tokens(sections)
    results = []
    message = ''

    sections.each do |section|
      if message.length + section.length <= SECTION_LIMIT
        message += section
      else
        results << message if message.present?
        message = section
      end
    end

    results << message if message.present?

    results
  end
end
