# frozen_string_literal: true

# The blocks /cv and /team/:person both render. Portfolio text carries inline <b>, <i> and
# <code>, so every field goes through ProseHelper's one sanitiser.
module Profile
  class BaseComponent < ViewComponent::Base
    delegate :rich, :plain, to: :helpers
  end
end
