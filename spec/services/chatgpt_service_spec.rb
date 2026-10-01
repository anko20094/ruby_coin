# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ChatgptService, type: :service do
  subject(:call_service) { VCR.use_cassette("chatgpt_service/#{cassette_name}") { described_class.call(params) } }

  let(:model) { ChatgptService::DEFAULT_MODEL }
  let(:locale) { 'uk' }
  let(:message) { '<h1>Привіт Світ</h1><p>Це тестова стаття для перекладу.</p>' }
  let(:params) { { input_data: message, locale: locale } }
  let(:cassette_name) { 'short_message' }

  describe '.call' do
    context 'when the message is short (under 90,000 characters)' do
      let(:cassette_name) { 'short_message' }

      it 'translates the content directly' do
        expect(call_service).to be_a(String)
        expect(call_service).not_to be_empty
      end

      context 'when translating from uk (Ukrainian) to en (English)' do
        let(:locale) { 'uk' }

        it 'initializes with correct translation prompts' do
          service = described_class.new(params)
          service.__send__(:choose_translation_language, locale)
          expect(service.instance_variable_get(:@input_locale)).to eq('Ukrainian')
          expect(service.instance_variable_get(:@output_locale)).to eq('English')
        end
      end

      context 'when translating from en (English) to uk (Ukrainian)' do
        let(:locale) { 'en' }
        let(:message) { '<h1>Hello World</h1><p>This is a test article for translation.</p>' }

        it 'initializes with correct translation prompts' do
          service = described_class.new(params)
          service.__send__(:choose_translation_language, locale)
          expect(service.instance_variable_get(:@input_locale)).to eq('English')
          expect(service.instance_variable_get(:@output_locale)).to eq('Ukrainian')
        end
      end
    end

    context 'when the message is extremely long (over 90,000 characters)' do
      let(:cassette_name) { 'long_message' }
      # Create a simulated long HTML structure
      let(:message) do
        headings = (1..6).map { |n| "<h2>Heading #{n}</h2><p>Paragraph text inside heading #{n}.</p>" }
        headings.join * 1000 # Make it long
      end

      before do
        # Stub the internal translation helper to avoid making concurrent network calls
        allow_any_instance_of(described_class).to receive(:translate)
          .and_return('<h2>Heading Translated</h2><p>Paragraph Translated</p>')
      end

      it 'divides, translates in parallel, and merges the sections successfully' do
        expect(message.length).to be > 90_000
        expect(call_service).to be_a(String)
        expect(call_service).not_to be_empty
        expect(call_service).to include('Translated')
      end
    end

    context 'when the API returns an error' do
      let(:cassette_name) { 'api_error' }

      it 'raises an Error with the API error message' do
        expect { call_service }.to raise_error(described_class::Error, 'OpenAI API internal server error')
      end
    end

    # What comes back from the model is stored as the article, so only a finished, non-empty
    # completion counts as one.
    context 'when the answer is not a usable translation' do
      subject(:call_service) { described_class.call(params) }

      def answer(code: 200, body: nil)
        allow(HTTParty).to receive(:post).and_return(instance_double(HTTParty::Response, code:, parsed_response: body))
      end

      def completion(finish_reason:, content:)
        { 'choices' => [{ 'finish_reason' => finish_reason, 'message' => { 'content' => content } }] }
      end

      it 'refuses an answer the model cut off' do
        answer(body: completion(finish_reason: 'length', content: '<p>Half a transl'))

        expect { call_service }.to raise_error(described_class::Error, /stopped early/)
      end

      it 'refuses an answer the model withheld' do
        answer(body: completion(finish_reason: 'content_filter', content: nil))

        expect { call_service }.to raise_error(described_class::Error, /stopped early/)
      end

      it 'refuses an empty answer' do
        answer(body: completion(finish_reason: 'stop', content: ''))

        expect { call_service }.to raise_error(described_class::Error, /empty/)
      end

      it 'refuses a reply that is not JSON, without a NoMethodError' do
        answer(code: 502, body: '<html>Bad gateway</html>')

        expect { call_service }.to raise_error(described_class::Error, 'OpenAI answered 502')
      end

      it 'refuses an empty body' do
        expect { described_class.call(input_data: '', locale: 'uk') }.to raise_error(described_class::Error)
      end

      it 'turns a timeout into the same Error' do
        allow(HTTParty).to receive(:post).and_raise(Net::ReadTimeout)

        expect { call_service }.to raise_error(described_class::Error, /Net::ReadTimeout/)
      end

      it 'waits no longer than TIMEOUT for the API' do
        answer(body: completion(finish_reason: 'stop', content: '<p>Hello</p>'))

        call_service

        expect(HTTParty).to have_received(:post).with(anything, hash_including(timeout: described_class::TIMEOUT))
      end
    end

    context 'when the message is long enough to be sent in sections' do
      let(:message) { (1..40).map { |n| "<h2>Heading #{n}</h2><p>#{'text ' * 3000}</p>" }.join }

      it 'never has more than MAX_PARALLEL sections in the air' do
        running = Concurrent::AtomicFixnum.new
        peak = Concurrent::AtomicFixnum.new
        allow_any_instance_of(described_class).to receive(:translate) do
          peak.update { |seen| [seen, running.increment].max }
          sleep 0.01
          running.decrement
          '<p>done</p>'
        end

        described_class.call(input_data: message, locale: 'uk')

        expect(peak.value).to be_between(2, described_class::MAX_PARALLEL)
      end

      it 'keeps the sections in order' do
        sections = 0
        lock = Mutex.new
        allow_any_instance_of(described_class).to receive(:translate) do |_service, section|
          lock.synchronize { sections += 1 }
          section[/Heading \d+/]
        end

        result = described_class.call(input_data: message, locale: 'uk')

        expect(result.scan(/Heading \d+/)).to eq(result.scan(/Heading \d+/).sort_by { |label| label[/\d+/].to_i })
        expect(sections).to be > described_class::MAX_PARALLEL
      end
    end
  end

  describe '#divide_by_tags' do
    let(:service) { described_class.new(params) }

    it 'divides HTML content by heading tags correctly' do
      html = '<h1>Header 1</h1><p>Text 1</p><h2>Header 2</h2><p>Text 2</p>'
      doc = Nokogiri::HTML(html)
      sections = service.__send__(:divide_by_tags, doc)
      expect(sections.map(&:strip)).to include(
        "<h1>Header 1</h1>\n<p>Text 1</p>",
        "<h2>Header 2</h2>\n<p>Text 2</p>"
      )
    end
  end
end
