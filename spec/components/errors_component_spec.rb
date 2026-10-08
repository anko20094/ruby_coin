# frozen_string_literal: true

require 'rails_helper'

describe ErrorsComponent, type: :component do
  let(:record) do
    Tag.new.tap { |tag| tag.errors.add(:title, :blank) }
  end

  it 'lists every message in a region that is announced' do
    render_inline(described_class.new(object: record))

    expect(page).to have_css('.mg-errors[role="alert"] li', count: record.errors.count)
  end

  it 'wears the theme skin on the site' do
    render_inline(described_class.new(object: record, tone: :site))

    expect(page).to have_css('.au-errors[role="alert"] li')
  end

  it 'renders nothing for a record without errors, or for no record at all' do
    render_inline(described_class.new(object: Tag.new))
    expect(rendered_content).to be_blank

    render_inline(described_class.new(object: nil))
    expect(rendered_content).to be_blank
  end

  it 'refuses a tone it has no skin for' do
    expect { described_class.new(object: record, tone: :loud) }.to raise_error(ArgumentError)
  end
end
