# frozen_string_literal: true

class PostCoverComponentPreview < ViewComponent::Preview
  # A post with no cover: the stone, in the shade its id picks, where a grey box used to be.
  # @param id number
  def without_cover(id: 3)
    post = Post.new(id: id.to_i, title: 'Rebuilt the pipeline on Propshaft')
    render_with_template(locals: { post: })
  end
end
