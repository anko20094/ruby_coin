# frozen_string_literal: true

require 'rails_helper'

# The drawer is driven by theme/nav_controller.js, which no spec here can run; what the markup
# promises it is pinned.
describe NavComponent, type: :component do
  before do
    I18n.with_locale(:en) do
      with_request_url('/en/work') { render_inline(described_class.new(current: :work)) }
    end
  end

  # Bubbling, a button elsewhere on the page has already run by the time the drawer is told
  # the tap was outside it.
  it 'hears a tap outside the drawer before whatever it landed on does' do
    expect(page.find('nav.rc-nav')['data-action']).to include('click@window->nav#outside:capture')
  end
end
