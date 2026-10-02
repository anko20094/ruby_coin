# frozen_string_literal: true

# The roster, and one canonical page per person.
#
# Not in the main nav: it is reached from /studio, from the footer, from the foot of every
# case page and from ⌘K. A person page arrived at through a project pins that project's
# contribution above the CV, which is the whole point of the design — the visitor came asking
# "what did this person do on that project" and must not have to scroll for the answer.
class TeamController < ApplicationController
  def index
    @people = Team.crew
    @order = Case.slugs

    cache_publicly(@order)
  end

  def show
    @person = Team.person!(params.expect(:id))
    raise ActiveRecord::RecordNotFound, "#{@person.id} has nothing behind the name" if @person.alumni? && !@person.page?

    @cases_by_slug = Case.ordered.index_by(&:slug)
    # Ordered by the projects' own display order, which is also the list of projects that
    # still exist — one that has left the portfolio does not leave a dead row behind.
    @contributions = @person.contributions(order: @cases_by_slug.keys)
    # The project the reader came through, if they came through one. Silently ignored when it
    # names a project this person did not work on, so a stale link degrades to the plain page.
    @context = @contributions.find { |contribution| contribution.slug == params[:from] }

    # The cases are in the key because the page prints their titles — in the breadcrumb, in the
    # pinned contribution and in every "worked on" row. They are editable in the admin, so a
    # renamed or deleted project has to be able to expire this page; without them the recomputed
    # ETag matches the old one forever and the reader keeps a page naming a project that is gone.
    cache_publicly([@person.id, @context&.slug, @cases_by_slug.values])
  end
end
