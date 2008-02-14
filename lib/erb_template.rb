# main class for ERB template rendering
require 'erb'

class ErbTemplate < BaseDrop
  include UrlFilters
  include DropFilters
  include CoreFilters

  def initialize(site)
    @site_source = site
  end

  def liquify(*records, &block)
    self.class.liquify(@context, *records, &block)
  end
  
  def render(section, layout, template, assigns ={}, controller = nil)
    @layout = layout
    @template = template
    @controller = controller
    @assigns = assigns
    # psq-TODO: assigns contains mode, site, articles, section (more or less depending on mode,
    # consider using missing method to expose all of them to templates)
    # "section" would be nicer than
    # "@assigns['section']"
    @context = ::Liquid::Context.new(assigns, {}, false) # assigns, register, rethrow error

    @mode = assigns['mode']
    @archive_date = assigns['archive_date']

    @articles = assigns['articles']
    @articles.each { |article| article.context = @context } if (@articles)
    @article = assigns['article']
    @article.context = @context if @article
    
    # form handling
    @submitted = @context['submitted'] || {}
    @submitted.each{ |k, v| @submitted[k] = CGI::escapeHTML(v) }
    @errors = @context['errors']
    @message = @context['message']

    @site = @site_source.to_liquid
    @site.context = @context
    if (section)
      @section = section.to_liquid
      @section.context = @context
    end

    to_html
  end


# entry point for rendering layout and main_template to html
# not reentrant at this point because of the use of @ouput and @binding
  def to_html
    @binding = get_binding #use the same binding throughout
    do_include(@layout)
  end
  
# 
# in layout, include content using chosen template
# <% main_content %>
#
  def main_content
    do_include(@template)
  end

# include template
# <% include "template name" %>
  def include(template)
    RAILS_DEFAULT_LOGGER.debug("do_include: #{template}")
    do_include(@site_source.find_preferred_template(:page, template+".rhtml"))
  end

  def block(position, section)
    return unless section
    block = Block.find(:first,
                        :conditions => ['position = ? and blocks_sections.section_id = ?', position, section.source.id],
                        :joins => 'inner join blocks_sections on blocks.id = blocks_sections.block_id')
    block.to_liquid if block
  end

# renders a block of liquid code
  def liquid_block(block)
    Liquid::Template.parse(block).render(@context)
  end
  
protected
  def do_include(erb_template)
    # need to save/restore @output since everything is using the same binding.
    # psq-TODO: if page caching is not working well enough, keeping a compiled version of the template could help
    # see ActionView::CompiledTemplates
    begin
      RAILS_DEFAULT_LOGGER.debug("do_include: #{erb_template}")
      saved_output = @output
      result = ERB.new(erb_template.read.to_s, nil, nil, "@output").result @binding
      @output = saved_output
      result
    rescue Exception => e  # errors from template code
      RAILS_DEFAULT_LOGGER.debug "ERROR: compiling #{erb_template} RAISED #{e}"
      RAILS_DEFAULT_LOGGER.debug "Backtrace: #{e.backtrace.join("\n")}"
      raise "ERB Error: #{$!}"
    end
  end

  def get_binding
    binding
  end
end
