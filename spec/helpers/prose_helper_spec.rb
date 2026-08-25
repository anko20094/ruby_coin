# frozen_string_literal: true

require 'rails_helper'

describe ProseHelper do
  describe '#rich' do
    it 'keeps the inline tags the content relies on' do
      value = 'a <b>bold</b> <i>number</i> in <code>upsert_all</code>'

      expect(helper.rich(value)).to eq(value)
    end

    # Case fields are written in TinyMCE now, and its toolbar offers a link. A sanitiser that
    # allows what the toolbar can make is the whole contract: anything the author watches
    # appear in the editor and then lose on save is worse than a toolbar without the button.
    it 'keeps a link, because the case editor can make one' do
      value = 'read <a href="/en/work/dna">the case</a>'

      expect(helper.rich(value)).to eq(value)
    end

    it 'strips script, and anything block-level' do
      expect(helper.rich('<script>alert(1)</script>')).to eq('alert(1)')
      # A case field is printed inside the design's own <p>, <li> or <h3>.
      expect(helper.rich('<p>one</p><h2>two</h2>')).to eq('onetwo')
    end

    it 'strips an event handler off a tag it otherwise keeps' do
      expect(helper.rich('<b onclick="alert(1)">x</b>')).to eq('<b>x</b>')
    end

    it 'passes nil through without raising' do
      expect(helper.rich(nil)).to be_nil
    end
  end

  describe '#plain' do
    it 'gives the words back without the markup' do
      expect(helper.plain('users across <b>2,488</b> chats')).to eq('users across 2,488 chats')
    end

    it 'is what a <title>, an OG card and the clipboard get' do
      expect(helper.plain(nil)).to eq('')
      expect(helper.plain('  <i>DNA</i>  ')).to eq('DNA')
    end
  end
end
