# frozen_string_literal: true

require 'rails_helper'

describe Admin::ListsHelper do
  let(:path) { ->(**query) { "/en/management/posts?#{query.to_query}" } }

  def sort_link(key, **params)
    helper.params.merge!(params)
    Capybara.string(helper.mg_sort_link(key, key, path: path)).first('a')
  end

  describe '#mg_sort_link' do
    context 'with no sort given' do
      it 'draws the arrow for the order on screen, newest first, and links to the opposite' do
        link = sort_link('updated')

        expect(link[:class]).to include('is-current')
        expect(link.find('.mg-table__arrow', visible: :all).text).to eq('↓')
        expect(link[:href]).to include('direction=asc')
      end

      it 'leaves the other columns without an arrow, and links them to descending' do
        link = sort_link('status')

        expect(link[:class]).not_to include('is-current')
        expect(link).to have_no_css('.mg-table__arrow', visible: :all)
        expect(link[:href]).to include('direction=desc')
      end
    end

    context 'with the column already sorted ascending' do
      it 'draws an up arrow and links to descending' do
        link = sort_link('status', sort: 'status', direction: 'asc')

        expect(link.find('.mg-table__arrow', visible: :all).text).to eq('↑')
        expect(link[:href]).to include('direction=desc')
      end
    end

    context 'with the column sorted descending' do
      it 'draws a down arrow and links to ascending' do
        link = sort_link('number', sort: 'number', direction: 'desc')

        expect(link.find('.mg-table__arrow', visible: :all).text).to eq('↓')
        expect(link[:href]).to include('direction=asc')
      end
    end

    it 'keeps the arrow out of the accessible name, which aria-sort already carries' do
      link = sort_link('updated')

      expect(link.find('.mg-table__arrow', visible: :all)['aria-hidden']).to eq('true')
    end
  end

  describe '#mg_aria_sort' do
    it 'is descending for the default order and nothing for the other columns' do
      expect(helper.mg_aria_sort('updated')).to eq('descending')
      expect(helper.mg_aria_sort('status')).to be_nil
    end

    it 'follows the direction in the params' do
      helper.params.merge!(sort: 'number', direction: 'asc')

      expect(helper.mg_aria_sort('number')).to eq('ascending')
      expect(helper.mg_aria_sort('updated')).to be_nil
    end

    it 'names no column while a search is in relevance order' do
      helper.params[:query] = 'rails'

      expect(helper.mg_aria_sort('updated')).to be_nil
    end

    it 'names the column again when a search is sorted explicitly' do
      helper.params.merge!(query: 'rails', sort: 'updated', direction: 'asc')

      expect(helper.mg_aria_sort('updated')).to eq('ascending')
    end
  end
end
