require 'sketchup'

class JF_LDrawPositioner

  def activate
    #Sketchup.active_model.entities.add_cpoint(@target)
    @sel = Sketchup.active_model.selection[0]
    if ! @sel.is_a? Sketchup::ComponentInstance
      puts "Selection is not an Instance."
      return
    end
    Sketchup.active_model.selection.clear
    Sketchup.active_model.active_view.invalidate
    @dist = 20
    @shift = false
    @ctrl = false
    @alt = false
  end #activate

  def onKeyUp(key, repeat, flags, view)
    if key == VK_SHIFT
    @shift = false
    end
    if key == VK_CONTROL
    @ctrl = false
    end
    @alt = false
  end

  def c(v)
    puts "c:#{v}"
  end

  def onKeyDown(key, repeat, flags, view)
    Sketchup.active_model.shadow_info["DisplayShadows"] = false
    puts "\nonKeyDown:"
    puts "  key: #{key}"
    puts "  repeat: #{repeat}"
    puts "  flags: #{flags}"
    puts "  shift: #{@shift}"
    quad = get_quad
    puts "quad: #{quad}"


    if key == VK_SHIFT
      @shift = true
    end
    if key == VK_CONTROL
      @ctrl = true
    end
    return if key == VK_SHIFT
    if key == VK_HOME
      x, y = get_axis
      puts "(#{x}, #{y})"
    end

    if key == VK_RIGHT # right
      puts "right:"
      axis = get_axis
      puts "axis: #{axis}"
      if axis == "x" and quad == 2
	vec = X_AXIS.clone
	dist = @sel.bounds.width
      end
      if axis == "x" and quad == 1
	vec = X_AXIS.reverse
	dist = @sel.bounds.width
      end
      if axis == "y" and quad == 2
	vec = Y_AXIS.clone
	dist = @sel.bounds.height
      end
      if axis == "y" and quad == 1
	vec = Y_AXIS.clone
	dist = @sel.bounds.height
      end
      if axis == "x" and quad == 4
	vec = X_AXIS.reverse
      end
      if axis == "y" and quad == 4
	vec = Y_AXIS.reverse
      end
      if axis == "y" and quad == 3
	vec = Y_AXIS.reverse
	dist = @sel.bounds.height
      end
      if axis == "x" and quad == 3
	vec = X_AXIS.clone
      end
    end

    if key == VK_LEFT # right
      puts "left:"
      axis = get_axis
      puts "axis: #{axis}"
      if axis == "x" and quad == 2
	vec = X_AXIS.reverse
	dist = @sel.bounds.width
      end
      if axis == "y" and quad == 2
	vec = Y_AXIS.reverse
	dist = @sel.bounds.height
      end
      if axis == "y" and quad == 1
	vec = Y_AXIS.reverse
	dist = @sel.bounds.height
      end
      if axis == "x" and quad == 1
	vec = X_AXIS.clone
	dist = @sel.bounds.width
      end
      if axis == "x" and quad == 4
	vec = X_AXIS.clone
      end
      if axis == 'y' and quad == 4
	vec = Y_AXIS.clone
      end
      if axis == "y" and quad == 3
	vec = Y_AXIS.clone
	dist = @sel.bounds.height
      end
      if axis == "x" and quad == 3
	vec = X_AXIS.reverse
      end
      #vec = compare_axes.reverse
      #vec.length = 20
      #@sel.transform! vec
    end
    if key == VK_UP
      puts "up:"
      axis = get_axis
      puts "axis: #{axis}"
      if @shift
	o = @sel.transformation.origin
	tr = Geom::Transformation.rotation(o, Z_AXIS, 90.degrees)
	@sel.transform! tr
	return
      end
      if axis == "x" and quad == 3
	vec = Y_AXIS.clone
	dist = @sel.bounds.height
      end
      if axis == "y" and quad == 2
	vec = X_AXIS.reverse
	dist = @sel.bounds.width
      end
      if axis == "y" and quad == 1
	vec = X_AXIS.reverse
	dist = @sel.bounds.width
      end
      if axis == "x" and quad == 2
	vec = Y_AXIS.clone
	dist = @sel.bounds.height
      end
      if axis == "x" and quad == 1
	vec = Y_AXIS.reverse
	dist = @sel.bounds.height
      end
      if axis == "y" and quad == 3
	vec = X_AXIS.clone
	dist = @sel.bounds.height
      end
      #vec = compare_axes
      #vec.length = 20
      #@sel.transform! vec
    end
    if key == VK_DOWN
      puts "down:"
      axis = get_axis
      puts "axis: #{axis}"
      if axis == "y" and quad == 3
	vec = X_AXIS.reverse
	dist = @sel.bounds.height
      end
      if axis == "x" and quad == 3
	vec = Y_AXIS.reverse
	dist = @sel.bounds.height
      end
      if axis == "y" and quad == 2
	vec = X_AXIS.clone
	dist = @sel.bounds.width
      end
      if axis == "x" and quad == 2
	vec = Y_AXIS.reverse
	dist = @sel.bounds.height
      end
      if axis == "y" and quad == 1
	vec = X_AXIS.clone
	dist = @sel.bounds.width
      end
      if axis == "x" and quad == 1
	vec = Y_AXIS.clone
	dist = @sel.bounds.height
      end
      #vec = compare_axes
      #vec.length = 20
      #@sel.transform! vec
    end
    if @ctrl
      vec.length = dist
      otr = @sel.transformation
      pt = @sel.transformation.origin
      ins = Sketchup.active_model.entities.add_instance(@sel.definition, otr)
      #ins.transform! vec
    else
      vec.length = 20
    end
    @sel.transform! vec
    move_cam(vec)
  end #onKeyDown

  def move_cam(vec)
    cam = Sketchup.active_model.active_view.camera
    e = cam.eye
    t = cam.target
    #t = @sel.transformation.origin
    t = t.offset vec
    u = cam.up
    neweye = e.offset(vec)
    cam.set(neweye, t, u)
  end

  def deactivate(view)
    view.invalidate
  end

  def get_quad
    cam = Sketchup.active_model.active_view.camera
    cam_loc = cam.eye
    target = cam.target
    #puts "cam_loc: #{cam_loc.inspect}"
    vec = target.vector_to(cam_loc)
    #puts "vec: #{vec.inspect}"
    x, y, z = vec.to_a
    #p x, y, z
    if x > 0 and y > 0
      # quad 1
      return 1
     end
    if x > 0 and y < 0
      # quad 2
      return 2
    end
    if x < 0 and y < 0
      # quad 3
      return 3
    end
    if x < 0 and y > 0
      # quad 4
      return 4
    end
  end

  def get_axis
    camera_dir = Sketchup.active_model.active_view.camera.direction
    x = camera_dir.angle_between(X_AXIS).radians
    y = camera_dir.angle_between(Y_AXIS).radians
    z = camera_dir.angle_between(Z_AXIS).radians
    # closer to 90
    x1 = (90 - x).abs
    y1 = (90 - y).abs
    #small = [x, y].min
    small = [x1, y1].min
    if small == x1
      return "x"
    else
      return "y"
    end
  end

  def get_axis
    cam_dir = Sketchup.active_model.active_view.camera.direction
    x, y, z = cam_dir.to_a
    [x, y]
    x = x.abs
    y = y.abs
    if x < y
      return "x"#["x", x]
    else
      return "y"#["y", y]
    end
  end

  def draw(view)
    puts "draw"
    view.draw_points(@sel.transformation.origin, 10, 7, "red")
  end


end #class

unless( file_loaded?(__FILE__))
  #UI.menu("Plugins").add_item("LDraw Positioner") { Sketchup.active_model.select_tool JF_LDrawPositioner.new }
  #file_loaded __FILE__
end
