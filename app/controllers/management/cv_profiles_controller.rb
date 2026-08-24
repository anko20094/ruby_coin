# frozen_string_literal: true

module Management
  # The CV frame is a singleton, so there is one screen and no index: edit and update.
  class CVProfilesController < ApplicationController
    before_action :authorize_policy

    def edit
      @profile = CVProfile.current
    end

    def update
      @profile = CVProfile.current

      if @profile.update(profile_params)
        flash[:success] = t('.success')
        redirect_to edit_management_cv_profile_path
      else
        render :edit, status: :unprocessable_content
      end
    end

    private

    def profile_params
      params.expect(cv_profile: [:figures_as_of, *localised_keys, { contact_rows: {} }])
    end

    def localised_keys
      CVProfile::LOCALISED_SCALARS.flat_map do |field|
        I18n.available_locales.map { |locale| :"#{field}_#{locale}" }
      end
    end

    def authorize_policy
      authorize [:management, CVProfile]
    end
  end
end
