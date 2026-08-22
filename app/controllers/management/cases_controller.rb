# frozen_string_literal: true

module Management
  class CasesController < ApplicationController
    before_action :authenticate_user!, :authorize_policy
    before_action :set_case!, only: %i[edit update destroy]

    def index
      @cases = Case.ordered
    end

    def new
      @case = Case.new(position: next_position, mark: format('%02d', next_position))
    end

    def edit; end

    def create
      @case = Case.new(case_params)

      if @case.save
        flash[:success] = t('.success')
        redirect_to management_cases_path
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      if @case.update(case_params)
        flash[:success] = t('.success')
        redirect_to management_cases_path
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @case.destroy

      flash[:success] = t('.success')
      redirect_to management_cases_path, status: :see_other
    end

    private

    def set_case!
      @case = Case.find(params.expect(:id))
    end

    def next_position
      (Case.maximum(:position) || 0) + 1
    end

    # The structured fields arrive as index-keyed hashes and are permitted wholesale; Case
    # keeps only the keys it declares, so nothing else can reach a column. See Case::STRUCTURES.
    def case_params
      params.expect(case: [*plain_keys, *localised_keys, *structure_keys])
    end

    def plain_keys
      %i[slug mark position own is_this_site year sector status stack_list]
    end

    def localised_keys
      Case::LOCALISED_SCALARS.flat_map do |field|
        I18n.available_locales.map { |locale| :"#{field}_#{locale}" }
      end
    end

    def structure_keys
      [Case::STRUCTURES.keys.to_h { |field| [:"#{field}_rows", {}] }]
    end

    def authorize_policy
      authorize [:management, Case]
    end
  end
end
