# frozen_string_literal: true

require 'rails_helper'

# TinyMCE loads a plugin from public/tinymce at runtime, by name. A plugin the editor asks for
# and the copy script did not bring over fails as a 404 and a silently smaller toolbar — the
# editor still opens, so nothing here would go red without this file. Which is the case worth
# guarding: the whole reason the editor was rebuilt is that its toolbar looked too small.
describe 'the self-hosted TinyMCE build' do # rubocop:disable RSpec/DescribeClass
  # rubocop:disable Rails/FilePath -- the autocorrect duplicates segments of paths this long
  let(:controller_source) { Rails.root.join('app/javascript/controllers/tinymce_controller.js').read }
  let(:copy_script) { Rails.root.join('bin/copy_tinymce.mjs').read }
  let(:packaged_plugins) { Rails.root.join('node_modules/tinymce/plugins') }
  # rubocop:enable Rails/FilePath

  # Both profiles: the post editor's array, and the case editor's space-separated string.
  def plugins_the_editor_asks_for
    listed = controller_source.scan(/plugins:\s*(\[.*?\]|"[^"]*")/m).flatten

    listed.flat_map { |chunk| chunk.gsub(/["\[\],]/, ' ').split }.uniq
  end

  def plugins_the_copy_script_brings
    copy_script[/const PLUGINS = \[(.*?)\]/m, 1].scan(/"([a-z]+)"/).flatten
  end

  it 'copies every plugin either profile names' do
    missing = plugins_the_editor_asks_for - plugins_the_copy_script_brings

    expect(missing).to be_empty,
                       "bin/copy_tinymce.mjs does not copy: #{missing.join(', ')}"
  end

  it 'names only plugins that exist in the package' do
    skip 'node_modules is not installed' unless packaged_plugins.directory?

    packaged = packaged_plugins.children.select(&:directory?).map { |dir| dir.basename.to_s }
    unknown = plugins_the_copy_script_brings - packaged

    expect(unknown).to be_empty, "not in the tinymce package: #{unknown.join(', ')}"
  end

  it 'has actually been built into public/tinymce' do
    root = Rails.public_path.join('tinymce')
    skip 'run `yarn build:tinymce` first' unless root.directory?

    expect(root.join('tinymce.min.js')).to exist
    expect(root.join('VERSION')).to exist

    absent = plugins_the_editor_asks_for.reject { |name| root.join("plugins/#{name}/plugin.min.js").exist? }
    expect(absent).to be_empty, "not copied: #{absent.join(', ')}"
  end
end
