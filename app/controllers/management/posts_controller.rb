# frozen_string_literal: true

module Management
  class PostsController < ApplicationController
    # A working list, not a card grid: it shows more rows than the public journal does.
    PER_PAGE = 20

    # Sorting is server-side and on a whitelist, so a column name from the query string can
    # never reach the ORDER BY. Title is deliberately absent: it lives on the translations
    # table and sorting by it would mean a join per locale for very little.
    SORTS = {
      'number' => :entry_number, 'status' => :status, 'updated' => :updated_at,
      'created' => :created_at
    }.freeze

    before_action :authorize_policy
    before_action :set_post!, only: %i[destroy edit update autosave preview]
    before_action :fetch_tags, only: %i[new edit update]
    before_action :fetch_users, only: %i[new edit create update]
    before_action :normalize_main_post_param, only: %i[create update autosave]

    def index
      @counts = post_counts
      @pagy, @posts = pagy(listed_posts, limit: PER_PAGE, raise_range_error: true)
    end

    def new
      @post = Post.new
    end

    def create
      @post = current_user.posts.build
      authorize [:management, @post]

      if persist
        flash[:success] = t('.success')
        redirect_to management_posts_path
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      if persist
        flash[:success] = t('.success')
        redirect_to management_posts_path
      else
        render :edit, status: :unprocessable_content
      end
    rescue ActiveRecord::StaleObjectError
      # Nothing was written. The author's text stays in the form over the current version, so
      # the next Save takes it.
      @post.lock_version = Post.where(id: @post.id).pick(:lock_version)
      flash.now[:alert] = t('.conflict')
      render :edit, status: :conflict
    end

    # Autosave. Goes through the same save as #update — one path, so the two cannot drift —
    # and answers with what the editor's state indicator needs to say.
    #
    # One save can raise lock_version by more than one: Mobility's translation rows declare
    # `belongs_to :translated_model, touch: true`, so writing a title touches the post a second
    # time. Harmless, but it means the editor must take the version the server reports rather
    # than incrementing its own.
    #
    # A post has to be valid in the locale being edited to be saved at all, so "invalid" is a
    # real state of this screen and the indicator says which fields are missing rather than
    # pretending the save worked.
    def autosave
      if persist
        # The time, not the date: this says "your last keystroke is on disk", and it is read
        # many times a minute.
        render json: {
          status: 'saved', lock_version: @post.lock_version,
          at: Time.current.strftime('%H:%M:%S')
        }
      else
        render json: { status: 'invalid', errors: @post.errors.full_messages },
               status: :unprocessable_content
      end
    rescue ActiveRecord::StaleObjectError
      render json: { status: 'conflict' }, status: :conflict
    end

    # The preview follows the language tab, not the language of the admin's own chrome. It
    # used to render in I18n.locale whichever tab was open, so an editor writing Ukrainian
    # watched an English preview and had no way to see the page they were actually changing.
    def preview
      I18n.with_locale(preview_locale) do
        render partial: 'management/posts/preview',
               locals: { post: @post, locale: preview_locale }, layout: false
      end
    end

    def destroy
      @post.destroy

      flash[:success] = t('.success')
      redirect_to management_posts_path, status: :see_other
    end

    def translate
      render json: { data: ChatgptService.call(ai_translation_params) }
    rescue ChatgptService::Error => e
      Rails.logger.warn { "Translation failed: #{e.message}" }
      render json: { error: 'translation_failed' }, status: :bad_gateway
    end

    private

    # One save: the other-language title and subtitle are assigned through Mobility before it, so
    # a refusal from either leaves nothing behind. A refused save also leaves the form's version
    # as it came.
    def persist
      attributes = post_params
      loaded_version = nil
      saved = false

      ActiveRecord::Base.transaction do
        # Inside the transaction: the tag writer commits its own rows the moment it is assigned.
        @post.assign_attributes(attributes)
        loaded_version = @post.lock_version
        saved = Posts::Translator.call(@post, localization_params) && @post.save
        # An edit of only the other language changes no column on posts, so nothing else would
        # check the version it carries or move updated_at.
        @post.touch if saved && !@post.saved_changes?
        raise ActiveRecord::Rollback unless saved
      end

      @post.lock_version = loaded_version unless saved
      saved
    end

    def listed_posts
      posts = Post.all
      posts = posts.where(status: params[:status]) if Post.statuses.key?(params[:status])
      posts = posts.search_everywhere(params[:query]) if params[:query].present?
      posts = posts.reorder(sort_column => sort_direction) unless rank_ordered?
      posts.includes(:tags, :user, :translations, :rich_text_description_en, :rich_text_description_uk)
    end

    # While searching without an explicit sort, pg_search's own relevance order is the useful
    # one; asking for a column takes over.
    def rank_ordered?
      params[:query].present? && params[:sort].blank?
    end

    def sort_column
      SORTS.fetch(params[:sort]) { SORTS.fetch('updated') }
    end

    def sort_direction
      params[:direction] == 'asc' ? :asc : :desc
    end

    def preview_locale
      requested = params[:preview_locale].to_s.to_sym

      I18n.available_locales.include?(requested) ? requested : I18n.locale
    end

    def ai_translation_params
      params.permit(:input_data, :locale)
    end

    def post_params
      params.expect(post: [
                      :title, :subtitle, :status, :main_post, :photo, :slug, :lock_version, :user_id,
                      *Post::RICH_TEXT_BODIES.values, { tag_ids: [] }
                    ])
    end

    # The editor posts "true"/"false"; the column is a boolean. Only touched when the key is
    # actually there, so a request that does not mention main_post cannot silently unfeature a
    # post — which is what the old comparison against "active" did.
    def normalize_main_post_param
      post = params[:post]
      post[:main_post] = post[:main_post].to_s == 'true' if post.key?(:main_post)
      slug_param
    end

    def new_record?
      action_name == 'create'
    end

    def localization_params
      params.require(:post).permit(title_localizations: {}, subtitle_localizations: {}) # rubocop:disable Rails/StrongParametersExpect
    end

    def set_post!
      @post = Post.find(params.expect(:id))
    end

    def fetch_tags
      @tags = @post.present? ? @post.tags : []
    end

    def fetch_users
      @users = User.order(:nickname)
    end

    def authorize_policy
      authorize [:management, Post]
    end

    # The slug is derived from the English title, because that is what reads in a URL — but only
    # for a post being created, and only when the editor has not written one. Renaming an
    # existing post is the editor's decision, made in the slug field and kept by a Save:
    # autosave never writes it, so a half-typed slug is not a published URL.
    def slug_param
      return params[:post].delete(:slug) if action_name == 'autosave'
      return if params.dig('post', 'slug').present?
      return params[:post].delete(:slug) unless new_record?

      english_title = I18n.locale == :en ? params.dig('post', 'title') : params.dig('post', 'title_localizations', 'en')
      params[:post][:slug] = Post.unused_slug(english_title.to_s.parameterize) # rubocop:disable Rails/StrongParametersExpect
    end
  end
end
