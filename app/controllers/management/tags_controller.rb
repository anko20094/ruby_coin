# frozen_string_literal: true

module Management
  class TagsController < ApplicationController
    before_action :authorize_policy
    before_action :set_tag!, only: %i[destroy edit update]

    def index
      @tag = Tag.new
      load_tags!
    end

    def new
      @tag = Tag.new
    end

    def edit; end

    def create
      @tag = Tag.new(tag_params)

      if @tag.save
        respond_to do |format|
          format.html do
            flash[:success] = t('.success')
            redirect_to management_tags_path, status: :see_other
          end

          format.turbo_stream { flash.now[:success] = t('.success') }
        end
      else
        respond_to do |format|
          # Re-render, don't redirect: 422 is not a redirect status, so the browser stayed on
          # a bare "You are being redirected" page and the typed title was lost.
          format.html do
            load_tags!
            render :index, status: :unprocessable_content
          end

          format.turbo_stream { flash.now[:alert] = @tag.errors.full_messages.to_sentence }
        end
      end
    end

    def update
      if @tag.update(tag_params)
        respond_to do |format|
          format.html do
            flash[:success] = t('.success')
            redirect_to management_tags_path, status: :see_other
          end

          format.turbo_stream { flash.now[:success] = t('.success') }
        end
      else
        respond_to do |format|
          # Re-render, don't redirect: 422 is not a redirect status, so the browser stayed on
          # a bare "You are being redirected" page and the typed title was lost.
          format.html do
            load_tags!
            render :index, status: :unprocessable_content
          end

          format.turbo_stream { flash.now[:alert] = @tag.errors.full_messages.to_sentence }
        end
      end
    end

    def destroy
      @tag.destroy

      respond_to do |format|
        format.html do
          flash[:success] = t('.success')
          redirect_to management_tags_path, status: :see_other
        end

        format.turbo_stream { flash.now[:success] = t('.success') }
      end
    end

    private

    def load_tags!
      @pagy, @tags = pagy(policy_scope([:management, Tag]).order(created_at: :desc), limit: 8)
    end

    def tag_params
      params.expect(tag: [:title])
    end

    def set_tag!
      @tag = Tag.find params.expect(:id)
    end

    def authorize_policy
      authorize [:management, Tag]
    end
  end
end
