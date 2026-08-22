# frozen_string_literal: true

require 'rails_helper'

describe ProseHelper do
  describe '#rich' do
    it 'keeps the three inline tags the content relies on' do
      value = 'a <b>bold</b> <i>number</i> in <code>upsert_all</code>'

      expect(helper.rich(value)).to eq(value)
    end

    it 'strips anything else' do
      expect(helper.rich('<script>alert(1)</script><a href="/x">link</a>')).to eq('alert(1)link')
    end

    it 'passes nil through without raising' do
      expect(helper.rich(nil)).to be_nil
    end
  end
end
