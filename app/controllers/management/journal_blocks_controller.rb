# frozen_string_literal: true

module Management
  # Creates the block the slash menu just asked for and hands back what Trix needs to place
  # it: the signed global id, and the same partial the public page renders so the editor
  # shows the real thing rather than a placeholder.
  class JournalBlocksController < ApplicationController
    before_action :authenticate_user!

    def create
      authorize [:management, JournalBlock]

      block = JournalBlock.new(kind: params[:kind], payload: payload_params.to_h.compact_blank)

      if block.save
        render json: { sgid: block.attachable_sgid, content: block_content(block) }
      else
        render json: { errors: block.errors.full_messages }, status: :unprocessable_content
      end
    end

    private

    def payload_params
      params.expect(payload: %i[language source tone body url caption])
    end

    def block_content(block)
      render_to_string(partial: 'journal_blocks/journal_block',
                       locals: { journal_block: block }, formats: [:html])
    end
  end
end
