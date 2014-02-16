
class ViewScope
  attr_reader :path, :html, :bindings
  attr_accessor :binding_number
  
  def initialize(handler, path)
    @handler = handler
    @path = path
    
    @html = ''
    @bindings = {}
    @binding_number = 0
  end
  
  def add_binding(content)
    case content[0]
    when '#'
  		command, *content = content.split(/ /)
  		content = content.join(' ')
      
      case command
      when '#if'
        add_if(content)
      when '#elsif'
        add_else(content)
      when '#else'
        if content.blank?
          add_else(nil)
        else
          raise "#else does not take a conditional #{content} was provided."
        end
      when '#each'
        add_each(content)
      end
    when '/'
      # close binding
      close_scope
    else
      # content
      add_content_binding(content)
    end
  end
  
  def add_content_binding(content)
    @handler.html << "<!-- $#{@binding_number} --><!-- $/#{@binding_number} -->"
    save_binding(@binding_number, "lambda { |__p, __t, __c, __id| ContentBinding.new(__p, __t, __c, __id, Proc.new { #{content} }) }")
    @binding_number += 1
  end
  
  def add_if(content)
    @handler.scope << IfViewScope.new(@handler, @path, content)
  end
  
  def add_else(content)
    raise "#else can only be added inside of an if block"
  end
  
  def add_each(content)
    @handler.scope << EachScope.new(@handler, @path, content)
  end
  
  # Called when this scope should be closed out
  def close_scope
    scope = @handler.scope.pop
    
    raise "template path already exists: #{scope.path}" if @handler.templates[scope.path]
    
    @handler.templates[scope.path] = {
      'html' => scope.html,
      'bindings' => scope.bindings
    }
  end
  
  def save_binding(binding_number, code)
    @bindings[binding_number] ||= []
    @bindings[binding_number] << code
  end
end