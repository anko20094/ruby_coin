# frozen_string_literal: true

module Management
  class PostsController < ApplicationController
    before_action :authenticate_user!, :authorize_policy, except: :translate
    before_action :set_post!, only: %i[show destroy edit update]
    before_action :fetch_tags, only: %i[new edit update]
    before_action :normalize_main_post_param, only: %i[create update]

    def index
      @posts = Post.order(created_at: :desc)
      @pagy, @posts = pagy(@posts, limit: 6)
    end

    def new
      @post = Post.new
    end

    def create
      @post = current_user.posts.build(post_params)

      authorize @post
      if @post.save && Posts::Translator.call(@post, localization_params)
        flash[:success] = t('.success')
        redirect_to management_posts_path
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      if @post.update(post_params) && Posts::Translator.call(@post, localization_params)
        respond_to do |format|
          format.html do
            flash[:success] = t('.success')
            redirect_to management_posts_path
          end

          format.turbo_stream do
            flash.now[:success] = t('.success')
          end
        end
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @post.destroy

      respond_to do |format|
        format.html do
          flash[:success] = t('.success')
          redirect_to management_posts_path, status: :see_other
        end

        format.turbo_stream { flash.now[:success] = t('.success') }
      end
    end

    def translate
      render json: { data: ChatgptService.call(ai_translation_params) }
    end

    private

    def ai_translation_params
      params.permit(:input_data, :locale)
    end

    def post_params
      params.expect(post: [
                      :title, :subtitle, :status, :main_post, :photo, :slug,
                      *Post::RICH_TEXT_BODIES.values, { tag_ids: [] }
                    ])
    end

    def normalize_main_post_param
      params[:post][:main_post] = params[:post][:main_post] == 'active' # rubocop:disable Rails/StrongParametersExpect
      slug_param
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

    def authorize_policy
      authorize [:management, Post]
    end

    def slug_param
      slug = I18n.locale == :en ? params.dig('post', 'title') : params.dig('post', 'title_localizations', 'en')
      params[:post][:slug] = slug&.parameterize # rubocop:disable Rails/StrongParametersExpect
    end
  end
end
