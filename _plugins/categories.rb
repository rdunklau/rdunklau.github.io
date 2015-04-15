# _plugins/categories.rb
require "rubygems"
require "bundler/setup"
Bundler.require(:default)

class PostContent < Liquid::Tag
  def initialize(tag_name, post, tokens)
    super
    @post = post
  end
  def render(context)
    post = context[@post.strip]
    site = context.registers[:site]
    converter = site.converters.find { |c| c.class == Jekyll::Converters::Markdown }
    partial = Liquid::Template.parse(converter.convert(post['content']))
    partial.render!(context)
  end
end

Liquid::Template.register_tag('render_post', PostContent)
