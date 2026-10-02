# frozen_string_literal: true

require 'rails_helper'

# Every Lookbook scenario renders. A preview nobody opens rots quietly; this is what notices.
describe 'component previews', type: :component do # rubocop:disable RSpec/DescribeClass
  include_context 'when the cases are imported'

  ViewComponent::Preview.all.each do |preview| # rubocop:disable Rails/FindEach -- an Array, not a relation
    preview.examples.each do |example|
      it "renders #{preview.name}##{example}" do
        with_request_url('/en') { render_preview(example, from: preview) }

        expect(rendered_content).to be_present
      end
    end
  end
end
