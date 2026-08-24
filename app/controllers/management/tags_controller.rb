# frozen_string_literal: true

module Management
  class TagsController < ApplicationController
    before_action :authorize_policy
    before_action :set_tag!, only: %i[destroy edit update]

    def index
      @tag = Tag.new
      @tags = policy_scope([:management, Tag]).order(created_at: :desc)
      @pagy, @tags = pagy(@tags, limit: 8)
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
          format.html { redirect_to management_tags_path, status: :unprocessable_content }
          format.turbo_stream { flash.now[:alert] = @tag.errors.full_messages.join }
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
          format.html { redirect_to management_tags_path, status: :unprocessable_content }
          format.turbo_stream { flash.now[:alert] = @tag.errors.full_messages.join }
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
