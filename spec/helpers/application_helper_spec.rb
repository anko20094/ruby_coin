# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  describe '#flash_stream' do
    let(:message) { I18n.t('management.tags.create.success') }

    it 'replaces the admin flash frame with the current messages' do
      flash[:notice] = message

      html = helper.flash_stream

      expect(html).to include('action="replace"', 'target="flash_message"')
      expect(html).to include('<turbo-frame id="flash_message">', 'rc-flash__item--notice', message)
    end
  end

  describe '#full_title' do
    it 'puts the site name after the page title' do
      expect(helper.full_title('Tags')).to eq("Tags | #{MetaHelper::SITE_NAME}")
      expect(helper.full_title).to eq(MetaHelper::SITE_NAME)
    end
  end

  describe '#view_transition_name' do
    it 'is the kind and the key, or nothing without a key' do
      expect(helper.view_transition_name('post-title', 7)).to eq('post-title-7')
      expect(helper.view_transition_name('post-title', nil)).to be_nil
    end
  end

  describe '#view_transition_style' do
    it 'names the record by kind and key' do
      expect(helper.view_transition_style('case-title', 'dna')).to eq('view-transition-name: case-title-dna')
    end

    it 'names nothing without a key' do
      expect(helper.view_transition_style('post-title', nil)).to be_nil
    end
  end
end
