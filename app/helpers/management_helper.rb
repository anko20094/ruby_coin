# frozen_string_literal: true

module ManagementHelper
  SIDEBAR_COOKIE = :mg_sidebar

  # Whether the sidebar rail starts shut.
  #
  # A cookie, not localStorage. The admin bundle is deferred and the admin's CSP allows no
  # inline script, so a class stamped by JavaScript would land after first paint — the sidebar
  # would flash open on every page load before snapping shut. A cookie rides the request, so
  # the layout can stamp the class server-side and the first paint is already correct.
  def management_sidebar_collapsed?
    cookies[SIDEBAR_COOKIE] == 'collapsed'
  end
end
