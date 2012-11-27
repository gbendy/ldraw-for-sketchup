require 'sketchup'

#unless( file_loaded?(__FILE__))
  #UI.menu("Plugins").add_item("Stud Stacker") {
    ##unless @ss_tool
    #@ss_tool = JFStudStacker.new 
    ##end
    #Sketchup.active_model.select_tool @ss_tool
  #}
  #file_loaded __FILE__
#end

#module Lego
  cmd = UI::Command.new("Stud Stacker") { Sketchup.active_model.select_tool JFStudStacker.new }
  #@cmds << cmd
#end
  UI.menu.add_item(cmd)

class JFStudStacker

  def dp(s)
    puts(s) if @dp
  end
  def initialize
    @hsnap = 10 # half of a single
    @vsnap = 8 # plate thickness
    @asnap = 45
  end

  def activate
    #Sketchup.active_model.entities.add_cpoint(@target)
    @sel = Sketchup.active_model.selection
    Sketchup.active_model.shadow_info["DisplayShadows"] = false
    Sketchup.active_model.active_view.invalidate
    @shift = @ctrl = @alt = false
    @dp = false
    @state = 0
      Sketchup.active_model.selection.clear
    Sketchup.status_text = "Select fisrt Stud."
  end #activate

  def reset
    Sketchup.status_text = "Select fisrt Stud."
      @state = 0
      Sketchup.active_model.selection.clear
  end

  def onLButtonDown flags, x, y, view
    dp "onLButtonDown:"
    ph = view.pick_helper
    ph.do_pick x, y
    pf = ph.picked_face
    o = ph.best_picked

    if o.nil?
      reset
    elsif o.is_a? Sketchup::ComponentInstance
      #Sketchup.active_model.selection.toggle(o)
    end


    if pf
      reset if @state > 2
      p pf
      parent = pf.parent
      p parent
      tr = ph.transformation_at 0
      if parent.is_a? Sketchup::ComponentDefinition
	#Sketchup.active_model.entities.add_cline(tr.origin, tr.zaxis)
	name = parent.name
	#if name[/stud/i]
	if @state == 0
	  Sketchup.active_model.selection.add(o)
	  @state += 1
	  @tr1 = tr
	  p @tr1.origin
	  @first = o
	  @a_rot = @tr1.origin
	  Sketchup.status_text = "Select target Stud."
	elsif @state == 1
	  @state += 1
	  @tr2 = tr
	  @a_rot = @tr2.origin
	  #Sketchup.active_model.entities.add_cline(@tr2.origin, @tr2.zaxis)
	  #@first.transformation = @tr2
	  dest = @tr2.origin
	  dest.z += @first.bounds.depth - 4.0
	  vec = dest - @tr1.origin
	  #@first.transform!(vec)
	  @sel.each {|e| e.transform!(vec)}
	  #@axis = @tr2.zaxis
	  #Sketchup.active_model.selection.clear
	  @state += 1
	  #reset
	end
      end
    end
  end

  def onKeyDown(key, repeat, flags, view)
    return if @a_rot.nil? or @state < 1
    if key == VK_RIGHT
      tr = Geom::Transformation.new(@a_rot, Z_AXIS, 45.degrees)
      @sel.each {|e| e.transform!(tr)}
    end
    if key == VK_LEFT
      tr = Geom::Transformation.new(@a_rot, Z_AXIS, -45.degrees)
      @sel.each {|e| e.transform!(tr)}
    end
  end

  def draw(view)
    p @state
    view.drawing_color = "blue"
    view.line_width = 2
    if @state > 0
      e = @a_rot.offset(Z_AXIS.clone, 120)
      view.draw_line(@a_rot, e)
    end
  end

end #class

