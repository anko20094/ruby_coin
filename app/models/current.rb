# frozen_string_literal: true

# State that lasts one request, or one job, and is dropped when it ends.
class Current < ActiveSupport::CurrentAttributes
  attribute :cv_rows

  # The CV row, read once per request: a person card, the footer and a page's date all ask, and
  # they have to agree. Held in an array so that "none imported yet" is remembered too.
  def cv_profile = (self.cv_rows ||= CVProfile.first(1)).first
end
