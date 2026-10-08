# frozen_string_literal: true

require 'rails_helper'

describe TinymceHelper do
  describe '#tinymce_valid_elements' do
    let(:elements) { helper.tinymce_valid_elements.split(',') }

    it 'allows the tags and attributes ProseHelper#rich keeps, and no others' do
      tags = elements.flat_map { |element| element[/\A[^\[]+/].split('/') }
      attributes = elements.flat_map { |element| element[/\[(.*)\]/, 1].to_s.split('|') }

      expect(tags).to match_array(ProseHelper::RICH_TAGS)
      expect(attributes.uniq).to match_array(ProseHelper::RICH_ATTRIBUTES)
    end

    it 'has the editor write bold and italic as <strong> and <em>' do
      expect(elements).to include('strong/b', 'em/i')
    end

    it 'puts each attribute on the tag that carries it' do
      expect(elements).to include('a[href|title|target|rel]', 'span[class]')
    end
  end

  describe '#tinymce_data' do
    it 'gives the case editor what it may produce and the language it holds' do
      data = helper.tinymce_data(profile: 'case', lazy: true, lang: 'uk')

      expect(data).to include(tinymce_profile_value: 'case', tinymce_lang_value: 'uk',
                              tinymce_valid_elements_value: helper.tinymce_valid_elements)
    end

    it 'gives the post editor no list of elements: what it may produce is the sanitiser list' do
      data = helper.tinymce_post_data

      expect(data[:tinymce_valid_elements_value]).to be_nil
      expect(data[:tinymce_lang_value]).to be_nil
    end
  end
end
