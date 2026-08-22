# frozen_string_literal: true

module Management
  class CVBlocksController < ApplicationController
    before_action :authenticate_user!, :authorize_policy
    before_action :set_block!, only: %i[edit update destroy]

    def index
      @blocks = CVBlock.ordered.group_by(&:kind)
    end

    def new
      kind = CVBlock::KINDS.include?(params[:kind]) ? params[:kind] : CVBlock::KINDS.first
      @block = CVBlock.new(kind: kind, position: next_position(kind))
    end

    def edit; end

    def create
      @block = CVBlock.new(block_params)

      if @block.save
        flash[:success] = t('.success')
        redirect_to management_cv_blocks_path
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      if @block.update(block_params)
        flash[:success] = t('.success')
        redirect_to management_cv_blocks_path
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @block.destroy

      flash[:success] = t('.success')
      redirect_to management_cv_blocks_path, status: :see_other
    end

    private

    def set_block!
      @block = CVBlock.find(params.expect(:id))
    end

    def next_position(kind)
      (CVBlock.where(kind: kind).maximum(:position) || 0) + 1
    end

    def block_params
      params.expect(cv_block: [:kind, :position, :period, :items_list, :case_slugs_list, *localised_keys])
    end

    def localised_keys
      CVBlock::PAYLOAD_KEYS.flat_map do |key|
        I18n.available_locales.map { |locale| :"#{key}_#{locale}" }
      end
    end

    def authorize_policy
      authorize [:management, CVBlock]
    end
  end
end
