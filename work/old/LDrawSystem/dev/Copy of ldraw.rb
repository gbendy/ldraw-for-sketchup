# ldraw.rb (C) 2006 jim.foltz@gmail.com
#
#
# Pathnames should be stored internally using the "/" separator
# and translations made when needed.
#
#
#   Components get exported as line-type 1: file reference
#   faces get exported as type 3 or 4
#
# Rotate before export {
# model = Sketchup.active_model
# entities = model.entities
# t = Geom::Transformation.rotation([0,0,0],[1,0,0],90.degrees)
# status = entities.transform_entities t, entities.collect
# }

require "sketchup.rb"

#require "All_Us_Scripts/delauney2.rb"
#require "ldraw/numeric.rb"
#require "dev/debug.rb"
#require "dev/corner_vertices.rb"


def dp(s)
  if $debug
    print ">" * @indent
    print " "
    puts s
  end
end



class Numeric
  unless defined? VERY_SMALL
    VERY_SMALL = 1e-4
    #adjust to taste
    def near_zero
      return 0.0 if between?(-VERY_SMALL, VERY_SMALL)
      self
    end
  end
end

module LDraw
  # Various Global Options
  #
  # Get default file locations
  @ldrawdir = Sketchup.read_default("LDraw", "LDrawDir")
  unless @ldrawdir
    @ldrawdir = "c:/ldraw/"
    Sketchup.write_default("LDraw", "LDrawDir", @ldrawdir)
  end
  @modeldir = Sketchup.read_default("LDraw", "ModelDir")
  unless @modeldir
    @modeldir = "#{@ldrawdir}models/"
    Sketchup.write_default("LDraw", "ModelDir", @modeldir)
  end

  # Skip components in this array. stud4 is a stud underneath bricks.
  #@exclude = ["stud4", "4-4edge", "2-4edge", "ring3", "stud3"]
  @exclude = []

  # future use: mpd files.
  @files = {}

  @parts_list = Hash.new(0)
  # ===========================================
  $debug = false
  @i = 0
  @indent = 0
  Sketchup.send_action("showRubyPanel:") if $debug
end



def LDraw.init
  @newlayer = nil
  @step = "Step 01"
  @do_steps = false
  @itr = Geom::Transformation.rotation(ORIGIN, X_AXIS, 90.degrees)
end


def LDraw.rot_all(angle)
  # Rotate before export
  model = Sketchup.active_model
  entities = model.entities
  t = Geom::Transformation.rotation([0,0,0],[1,0,0],angle.degrees)
  status = entities.transform_entities t, entities.collect
end

def LDraw.corner_vertices(face)
  face_edges = face.edges

  verts = face.vertices

  shared = []
  verts.each do |v|
    # for each vertex
    v_edges = v.edges
    edges = v_edges & face_edges
    Sketchup.active_model.selection.clear
    line1 = edges[0].line
    line2 = edges[1].line
    vec1 = line1[1]
    vec2 = line2[1]
    ab = (vec1.angle_between vec2).abs.radians
    if ab.near_zero == 180.0 or ab.near_zero == 0
      shared << v
    end
  end
  return [verts - shared].flatten
end


def LDraw.about
  UI.openURL("http://sketchuptips.blogspot.com/2007/08/plugin-ldrawrb.html")
end

def LDraw.open_model_dir
  UI.openURL(@modeldir)
end

def LDraw.config
  # Read defaults
  puts "=" * 10
  ret = UI.inputbox(["LDraw dir", "Model dir"], [ @ldrawdir ,  @modeldir ], "Configure LDraw Importer")
  return unless ret
  @ldrawdir = ret[0].gsub(/\\/, "/")
  @modeldir = ret[1].gsub(/\\/, "/")
  @ldrawdir += "/" unless @ldrawdir[-1] == 47
  @modeldir += "/" unless @modeldir[-1] == 47
  p @ldrawdir
  p @modeldir

  # Save settings
  a = Sketchup.write_default("LDraw", "LDrawDir", @ldrawdir)
  b = Sketchup.write_default("LDraw", "ModelDir", @modeldir)

  # =================
  # Display Settings
  # =================
  #Sketchup.send_action(10598) # enable transparency
end

def LDraw.read_colors
  #
  # read colors
  @colors = {}
  @color_code = {}
  IO.foreach("#{@ldrawdir}/ldconfig.ldr") do |line|
    ary = line.split
    next unless ary[1] == "!COLOUR"
    code = ary[4].strip
    name = ary[2]
    @colors[code] = ary
    @color_code[name] = code
  end
  #p @colors.keys.sort
end

def LDraw.add_materials
  self.read_colors if @colors.nil?
  @color_code.each do |name, v|
    ary = @colors[v]
    #p name,ary
    if(mat = Sketchup.active_model.materials[name])
      next
    end
    mat = Sketchup.active_model.materials.add name
    alpha = ary[10]
    alpha = (alpha ? alpha.to_i : 255) / 255.0
    # p ary[6]
    mat.color = Sketchup::Color.new(ary[6])
    mat.alpha = alpha 
  end
end


#
#
#
def LDraw.set_color(ent, code)
  self.read_colors unless @colors
  ary = @colors[code]
  return unless ary
  #return unless ent.typename == "ComponentInstance"
  #p code
  #p ary
  name = ary[2]
  if code == "16" or code == "24"
    name = ent.parent.material.name
  end
  if mat = Sketchup.active_model.materials[name]
    ent.material = mat
    if ent.respond_to?("back_material")
      ent.back_material = mat
    end
  else

    mat = Sketchup.active_model.materials.add name
    alpha = ary[10]
    alpha = (alpha ? alpha.to_i : 255) / 255.0
    #p ary[6]
    m = ary[6].match(/#(..)(..)(..)/)
      r=m[1].hex
    g=m[2].hex
    b=m[3].hex

    #mat.color = Sketchup::Color.new(ary[6])
    mat.color = Sketchup::Color.new(r, g, b)
    mat.alpha = alpha 
    dp "adding material #{mat.name} #{mat.inspect}"
    ent.material = mat
    dp "setting #{ent.inspect} to  #{mat.name}."
    if ent.respond_to?("back_material")
      dp "setting back #{ent.inspect} to #{mat.name}."
      ent.back_material = mat
    end
  end
end

#
#
#
def LDraw.importlast
  self.import(@file)
end

#
#
#
def LDraw.import_bynum(num = nil)
  if num.nil?
    ret = UI.inputbox(["Number"], [], "Enter Part Number")
    return unless ret
    num = ret[0].strip
    nums= num.split
  else
    num = num.to_s
  end

  nums.each do |num|
    s, e = num.split(/\.\./) 
    if( s )
      r = (s.to_i)..(e.to_i)
      r.each {|n| 
	file, r = get_path(n.to_s)
	self.import file
      }
    end
    num.gsub!(/\.dat/i, "")
    file, r = get_path( num )
    @file = file
    cdef = self.import(file) if file
    if cdef
      Sketchup.active_model.place_component cdef
    else
      puts "import_bynum: cdef is null:#{__LINE__}"
    end
  end
end

#
#
#
def LDraw.import_partslist(file = nil)
  if file.nil?
    dir = @ldrawdir.gsub("/", "\\\\")
    file = UI.openpanel("Import Parts List", "#{dir}", "*.*")
  end
  return unless file
  IO.readlines(file).each do |pn|
    path,r = get_path(pn.strip)
    self.import(path) if path
  end
end



############################################
#
def LDraw.import(file = nil)
  init()
  if file.nil?
    modeldir = @modeldir.gsub(/\//, "\\\\")
    file = UI.openpanel("Select a .dat File", modeldir, "*.dat;*.ldr")
    return unless file
    @do_steps = true
  end
  file.gsub!(/\\/, '/')
  split_mpd(file)
  puts "BEGIN #{file}"
  time1 = Time.now
  cname = File.basename(file)[0..-5]
  name = @step
  if @do_steps
    @newlayer = Sketchup.active_model.layers.add name
  end
  cdef = Sketchup.active_model.definitions[cname]
  if cdef
    cdef.entities.clear!
  else
    cdef = Sketchup.active_model.definitions.add(cname)
  end
  process_file(file, cdef, "16")
  # Remember last file imported
  @file = file
  UI.beep
  puts "Load time: #{Time.now - time1} seconds."
  cdef
end

def LDraw.validity_check
  Sketchup.send_action 21124 # validity check
end


#
# Can acceppt an index, a Page object, and a Scene name
def LDraw.gotoScene(o=0)
  pages = Sketchup.active_model.pages
  if o.is_a? Fixnum
    pages.selected_page = pages[o]
  end
  if o.is_a? Sketchup::Page
    pages.selected_page = o
  end
  if o.is_a? String
    pages.selected_page = pages[o]
  end
end

# pages index from 0
# (user) layers index from 1
def LDraw.layers_curr_prev # ladder
  layers = Sketchup.active_model.layers
  nlayers = layers.length
  pages = Sketchup.active_model.pages
  pages.each_with_index do |page, pi|
    layers.each_with_index do |layer, li|
      if( pi == li ) or (pi+1 == li)
	page.set_visibility(layers[li], true)
      else
	page.set_visibility(layers[li], false) if li > 0
      end
    end
  end
end

def LDraw.layers_stack # additive
  Sketchup.active_model.start_operation("Fix Layers", true)
  layers = Sketchup.active_model.layers
  pages = Sketchup.active_model.pages
  pages.each_with_index do |page, pi|
    #pages.selected_page = page
    layers.each_with_index do |layer, li|
      if li-1 <= pi
	page.set_visibility layer, true
      else
	page.set_visibility layer, false
      end
    end
    #page.update
  end
  Sketchup.active_model.commit_operation
end

def LDraw.getCurrScene()
  return Sketchup.active_model.pages.selected_page
end

# Sets camera to current view for all pages
# Does not set the zoom for all pages
# # TODO rename to a betyter name
def LDraw.zoom_all_pages
  curr_cam = Sketchup.active_model.active_view.camera
  c_eye = curr_cam.eye
  c_target = curr_cam.target
  c_up = curr_cam.up
  c_pers = curr_cam.perspective?
  #spage = getCurrScene()
  #Sketchup.active_model.start_operation("Zoom Extents Each Scene", true)
  #camera = Sketchup.active_model.active_view.camera
  #aview = Sketchup.active_model.active_view
  pages = Sketchup.active_model.pages
  Sketchup.active_model.pages.each do |page|
    #page.use_camera = false
    pages.selected_page = page
    camera = page.camera
    camera.perspective = c_pers
    camera.set(c_eye, c_target, c_up)
    #page.camera.set(camera.eye, camera.target, camera.up)
    #Sketchup.send_action("viewIso:")
    Sketchup.active_model.active_view.zoom_extents
    #JF.zoomOut(0.3)
    #page.update
  end
  #Sketchup.active_model.commit_operation
  #gotoScene(spage)
end

def LDraw.write_all_pages
  view = Sketchup.active_model.active_view
  pages = Sketchup.active_model.pages
  pages.each do |page|
    page.transition_time = 0
    pages.selected_page = page
    view.write_image("/tmp/"+page.name+".jpg")
  end
end




#
# Create component from disk file
#
def LDraw.process_file(file, cdef, color)
  @indent += 1
  flag = false
  #puts "processing: #{file}"
  lines = IO.readlines(file)
  ##p lines.length
  first_line = lines.shift.strip
  cdef.description = first_line[2..-1].to_s
  step = 1
  for line in lines
    line.strip!
    next if line.length == 0
    ary = line.split
    cmd = ary.shift

    case cmd

    when "0" # Comment/META
      meta = ary[0]
      case meta
      when "STEP"
	puts line
	if @do_steps
	  #puts format("Step %03d", step)
	  #step += 1
	  @step.next!
	  name = @step
	  @newlayer = Sketchup.active_model.layers.add name
	  #@newlayer.page_behavior = (LAYER_HIDDEN_BY_DEFAULT | LAYER_IS_VISIBLE_ON_NEW_PAGES)
	  #note = Sketchup.active_model.add_note(@step, 0.1, 0.1)
	  #note.layer = @newlayer
	  #page = Sketchup.active_model.pages.add name
	  #page.use_camera = false
	  #Sketchup.active_model.active_view.zoom_extents
	end
      end

    when "1" # file reference
      dp "file reference: #{ary.inspect}"
      c = ary.shift
      #p ary

      file = ary.pop
      cname = file[0..-5]
      if @exclude.include? cname
	puts "Ignoring request for #{cname}"
	next
      end
      ary.map!{|e| e.to_f}
      UI.messagebox("Bad array") if ary.length != 12
      # Is component already in model?
      if ndef = Sketchup.active_model.definitions[cname]
	#dp "using already defined #{cname}."
      elsif File.exist?(file = @ldrawdir + "/sketchup/" + cname + ".skp")
	# TODO look in Plugins/LDrawSystem/parts for SU models
	ndef = Sketchup.active_model.definitions.load(file)
      else
	#p cname
	file, prim = get_path(cname)
	#puts "[#{file}, #{r}]"
	if file
	  #cname = file2cname(file)
	  ndef = Sketchup.active_model.definitions.add(cname)
	  dp "adding new def #{cname} #{ndef.inspect} "
	  process_file(file, ndef, c)
	else
	  puts "Can't find #{cname}.dat"
	  #return
	end
      end
      UI.messagebox("No def") unless cdef
      #t2 = Geom::Transformation.rotation([0,0,0], [1,0,0], 90.degrees)
      t = array_to_transformation(ary)
      if cname == "977"
	p ary
	p t.to_a
      end
      ins = cdef.entities.add_instance(ndef, t)
      #ins.name = cdef.name
      #UI.start_timer(0.1) {}
      if( (!@newlayer.nil?) and (! prim ) )
	ins.layer = @newlayer 
      end
      #ins.transform! t2
      dp "adding instance #{ndef.name} #{ndef.inspect} -> #{ins.inspect}"
      self.set_color(ins, c)

    when "2" # line between 2 points
      #draw2(ary, cdef)

    when "3" # filled triangle between 3 points
      c = ary.shift
      draw3(ary, cdef, c)

    when "4" # filled quad between 4 points
      c = ary.shift
      draw4(ary, cdef, c)

    when "5" # optional line
      draw5(ary, cdef)

    else
      puts "an error occured."
    end # END case cmd
  end
  @indent -= 1
end

#########################################################
def LDraw.array_to_transformation(ary)
  x,y,z,a,b,c,d,e,f,g,h,i = ary
  r1 = [a, d, g, 0.0]
  r2 = [b, e, h, 0.0]
  r3 = [c, f, i, 0.0]
  r4 = [x, y, z, 1.0]
  #r1 = [a, b, c, x]
  #r2 = [d, e, f, y]
  #r3 = [g, h, i, z]
  #r4 = [0, 0, 0, 1.0]
  Geom::Transformation.new([r1, r2, r3, r4].flatten)
end

#################################################
#
#
def LDraw.get_path(name)
  file = @ldrawdir + "p/" + name + ".dat"
  return [file, true] if File.exist?(file)

  file = @ldrawdir + "parts/" + name + ".dat"
  if File.exist?(file) # is prim
    if file.include?("s\\")
      return [file, true]
    else
      return [file, false]
    end
  end
  file = "./" + name + ".dat"
  return [file,false] if File.exist?(file)

  file = "./" + name + ".ldr"
  return [file, false] if File.exist?(file)

  file = "c:/program files/lego draw/ldraw/p/" + name + ".dat"
  return file if File.exist?(file)

  file = "c:/program files/lego draw/ldraw/parts/" + name + ".dat"
  return file if File.exist?(file)

  # knex
  file = @ldrawdir + "knex/" + "p/" + name + ".dat"
  return file if File.exist?(file)

  file = @ldrawdir + "knex/" +  "parts/" + name + ".dat"
  return file if File.exist?(file)

  file = @modeldir + name + ".ldr"
  return file if File.exist?(file)

  file = @modeldir + name + ".dat"
  return file if File.exist?(file)

  return [false, false]
end

#
#
#
def LDraw.file2cname(file)
  #p file
  a = file.split('/')
  name = a[-2] + "/" + a[-1]
  #p name
end

#
#
#
def LDraw.draw2(ary, cdef)
  dp "+Line to #{cdef.name}: #{ary.inspect}"
  color = ary.shift
  ary.map! { |e| e.to_f  }
  p1, p2 = ary.slice!(0, 3), ary
  edge = cdef.entities.add_edges(p1, p2)
end

#
#
#
def LDraw.draw3(ary, cdef, color)
  dp "+Tri to #{cdef.name}: #{ary.inspect}"
  ary.map! {|e| e.to_f }
  pts = [ ary[0,3], ary[3,3], ary[6, 3] ]
  face = cdef.entities.add_face( pts )
  self.set_color(face, color)
end

#
#
#
def LDraw.draw4(ary, cdef, color)
  #color = ary.shift
  dp "+Quad to #{cdef.name}: #{ary.inspect}"
  ary.map! { |e| e.to_f }
  p1 = ary[0, 3]
  p2 = ary[3, 3]
  p3 = ary[6, 3]
  p4 = ary[9, 3]
  pts = [ p1, p2, p3, p4 ]#.uniq
  #pts.sort!
  #p pts
  #p self.swap_needed(pts)
  if self.swap_needed(pts)
    #puts "swap needed."
    if( !self.swap_needed([p1, p2, p4, p3]) )
      self.swap_points(pts, 2, 3)
    elsif( !self.swap_needed([p1, p3, p2, p4]) )
      self.swap_points(pts, 1, 2)
    end
  end

  #p pts
  #pts.each_with_index do |pt, i|
  #p pts[i-1].dot pts[i]
  #end
  ##pts = [ p1, p2, p4, p3 ]
  begin
    #mesh = Geom::PolygonMesh.new
    #pts.each { |pt| mesh.add_point(pt) }
    #mesh.add_polygon(p2, p3, p4)
    #p mesh.polygons
    #cdef.entities.add_faces_from_mesh mesh

    face = cdef.entities.add_face( pts )
    #p face.vertices.length
    #p face.edges.length
    #f2 = cdef.entities.add_face(face.outer_loop.vertices)
    #f1 = cdef.entities.add_face(p1, p2, p3)
    #f2 = cdef.entities.add_face(p1, p3, p4)
    #cdef.entities.add_text("#{@i += 1}", p1)
    self.set_color(face, color)

  rescue => e
    dp "!#{e} in file #{cdef.name}"
    #pts = [ p1, p2, p4, p3 ]
    #face = cdef.entities.add_face( pts )
    cdef.entities.add_face(p1, p2, p4)
    #Sketchup.active_model.entities.add_face(p1, p3, p2)
    cdef.entities.add_face(p2, p3, p4)
    #Sketchup.active_model.entities.add_face(p1, p3, p4)
    #UI.messagebox("pause")
    #pts.each_with_index { |pt, i| cdef.entities.add_text(i.to_s, pt) }
  end
end

#
#
#
def LDraw.draw5(ary, cdef)
  return
  dp "+Optional #{ary.inspect}"
  c = ary.shift
  ary.map! { |e| e.to_f }
  p1 = ary[0, 3]
  p2 = ary[3, 3]
  #p3 = ary[6, 3]
  #p4 = ary[9, 3]
  cdef.entities.add_cline(p1, p2)
end

#
#
#
def LDraw.make_steps
  Sketchup.active_model.start_operation("Make Steps")
  cdef = Sketchup.active_model.definitions[@file]
  if cdef
    cdef.entities.clear!
  end
  step = 1
  layer_name = format("Step %03d", step)
  #layer = Sketchup.active_model.active_layer
  layer = Sketchup.active_model.layers.add(layer_name)
  IO.readlines(@file).each do |line|
    line.strip!
    ary = line.split
    cmd = ary.shift
    color = "16"
    case cmd
    when "0"
      if ary[0] == "STEP"
	step += 1
      layer_name = format("Step %03d", step)
      layer = Sketchup.active_model.layers.add(layer_name)
      # layer.visible = false
      end
    next
    when "1"
      #p line
      color = ary.shift
      file = ary.pop
      file.gsub!(/.dat/i, "")
      #d{:file}
      #d{:color}
      ary.map!{|e| e.to_f}
      x,y,z,a,b,c,d,e,f,g,h,i = ary
      l1 = [a, d, g, 0.0]
      l2 = [b, e, h, 0.0]
      l3 = [c, f, i, 0.0]
      l4 = [x, y, z, 1.0]
      a = [l1, l2, l3, l4].flatten
      t = Geom::Transformation.new(a)
      cdef = Sketchup.active_model.definitions[file]
      #p file
      #p cdef.class
      ins  = Sketchup.active_model.entities.add_instance(cdef, t)
      #ins.name = cdef.name
      ins.layer = layer
      self.set_color(ins, color)
    when "2"
      draw2(ary, cdef)
    when "3"
      draw3(ary, cdef, color)
    when "4"
      draw4(ary, cdef, color)
    when "5"
      draw5(ary, cdef, color)
    end
    # Do a final rotate because LDraw and SketchUp have 
    # different views of the 3D world, apparently.
    # pt = [0,0,0]
    # v = Geom::Vector3d.new(1, 0, 0)
    # angle = -90.degrees  
    # t = Geom::Transformation.rotation(pt, v, angle)
    # gr.move!(t)
    # gr.explode

  end
  Sketchup.active_model.commit_operation
end

#
#
#
def LDraw.export(entities)
  begin
    self.read_colors unless @colors
    @exfile = "#{entities.parent.name}.dat"
    file = UI.savepanel("Export", "c:\\ldraw\\", @exfile)
    #file = @exfile
    #d{:file}
    fp = File.open(file, "w")
    #entities = Sketchup.active_model.active_entities
    faces = entities.select { |e| e.typename == "Face" }
    fp.puts "0 Faces"
    faces.each do |face|
      line = face2line(face)
      p line
      fp.puts line
    end
    fp.puts "0 Components"
    ci = entities.select { |e| e.is_a?  Sketchup::ComponentInstance }
    ci.each { |c| 
      #p c.material
      col = c.material.name.gsub(/[<>]/, "") unless c.material.nil?
      #p col
      p @color_code[col]
      fp.print "1 #{@color_code[col] || 16} "
      a = c.transformation.to_a
      #t = Geom::Transformation.rotation([0,0,0], [0,1,0], 90.degrees)
      puts "a=#{ a.inspect }"
      #a *= t
      # 12.upto(14) { |i| fp.print a[i] }
      #
      # x, y, z
      fp.print a[12..14].join(" ")
      fp.print " "
      #fp.print a[0..2].join(" ") 
      #fp.print " "
      #fp.print a[4..6].join(" ")
      #fp.print " "
      #fp.print a[8..10].join(" ")
      #fp.print " "
      [0, 4, 8].each {|i| fp.print "#{a[i]} " }
      [1, 5, 9].each {|i| fp.print "#{a[i]} " }
      [2, 6, 10].each {|i| fp.print "#{a[i]} " }
      n = c.definition.name.split('#')[0]
      fp.puts "#{n}.dat" # TODO
    }
    fp.puts "0"
    #fp.flush
    #fp.close
  ensure
    fp.flush
    fp.close
  end
end # export

def LDraw.face2line(face)
  line = ""
  verts = self.corner_vertices(face)
  pos = verts.map { |v| v.position }
  col = face.material.name.gsub(/[<>]/, "") unless face.material.nil?
  color = @color_code[col]
  color ||= "16"
  if verts.length == 3
    line << "3 #{color} "
  end
  if verts.length == 4
    line <<  "4 #{color} "
  end
  if verts.length <=4
    verts.each { |v|
      line << sprintf("%8.4f ", "#{v.position.x.near_zero.to_f}")
      line << sprintf("%8.4f ", "#{v.position.y.near_zero.to_f}")
      line << sprintf("%8.4f " , "#{v.position.z.near_zero.to_f}")
    }
    line << "\n"
  end
  line
end

#
#
#
def LDraw.export_model
  #path = "c:\\ldraw\\"
  read_colors unless @colors
  path = @modeldir.gsub(/\//, "\\\\")
  title = Sketchup.active_model.title
  title = "Untitled" if title.empty?
  title += ".dat"
  filename = UI.savepanel("Export model", path, title)
  return unless filename
  self.rot_all(90)
  #filename = path + "model.dat"
  fp = File.new(filename, "w")
  # Iterate Layers
  layers = Sketchup.active_model.layers
  # collection of all ComponentInstances
  f = "%.4f "
  layers.each do |layer|
    instances = []
    Sketchup.active_model.active_entities.each { |e|
      next unless e.is_a? Sketchup::ComponentInstance
      if e.layer.name == layer.name
	instances << e
      end
    }
    instances.each do |ins|
      # get color
      color = 16
      col = ins.material.name.gsub(/[<>]/, "") unless ins.material.nil?
      if @color_code
	color = @color_code[col] 
      else
	color = 16
      end
      color = 16 unless color
      # get transformation as array
      tt = ins.transformation
      #t = ins.transformation.to_a
      t = mod_trans(tt).to_a
      t = tt.to_a
      fp.print "1 #{color} "
      12.upto(14) { |i| fp.printf f,  "#{t[i]}" }
      [0, 4, 8].each {|i| fp.printf f, "#{t[i]}" }
      [1, 5, 9].each {|i| fp.printf f, "#{t[i]}" }
      [2, 6, 10].each {|i| fp.printf f, "#{t[i]}" }
      name = ins.definition.name.split('#')[0]
      fp.puts "#{name}.dat"
    end
    fp.puts "0 STEP" if instances[0]
  end
  faces = Sketchup.active_model.entities.select {|e| e.typename == "Face"}
  faces.each do |face|
    fp.puts face2line(face)
  end
  fp.flush
  fp.close
  self.rot_all(-90)
  UI.beep
  #ldview = %(c:\\Program Files\\LDView\\LDView )
  #p ldview
  #UI.openURL(ldview + File.basename(filename) )
  #system(ldview + File.basename(filename))
  #`#{ldview} #{ File.basename(filename)}`
  r = UI.messagebox("View exported file in LDView?", MB_YESNO)
  if r == 6
    write_batch(filename)
  end

end

def LDraw.mod_trans(tr)
  #return t
  t = tr.clone
  to = tr.clone
  tr1 = Geom::Transformation.rotation(ORIGIN, X_AXIS, -90.degrees)
  #tr2 = Geom::Transformation.rotation(t.origin, t.xaxis, -90.degrees)
  tr2 = Geom::Transformation.axes(ORIGIN, X_AXIS, Z_AXIS ,Y_AXIS)
  #tr2 = Geom::Transformation.rotation(ORIGIN, X_AXIS, 90.degrees)
  #tr2 = Geom::Transformation.rotation(ORIGIN, X_AXIS, 90.degrees)
  t2 = t * tr1# * tr2
  #t.set! t2
  #t =  t * tr2
  return (t2)
end


def LDraw.write_batch(file)
  fov = Sketchup.active_model.active_view.camera.fov
  pf = Sketchup.find_support_file("Plugins")
  ld = File.join(pf, "LDrawSystem")
  ldview_d = %(c:\\Program Files\\LDView)
  ldview = File.join(ldview_d , "\\ldview.exe")
  c =  %(start "" "#{ldview}" -FOV=#{fov} "#{file}")
  File.open(File.join(ld, "ldview.bat") , "w") { |f| f.puts c }
  UI.openURL(File.join(ld, "ldview.bat"))
end


def LDraw.new_step
  name = @step
  newlayer = Sketchup.active_model.layers.add name
  #newlayer.page_behavior = (LAYER_HIDDEN_BY_DEFAULT | LAYER_IS_VISIBLE_ON_NEW_PAGES)
  Sketchup.active_model.pages.add name
  Sketchup.active_model.active_entities.each do |e|
    next unless e.is_a? Sketchup::ComponentInstance
    p e.layer.name
    if e.layer.name == "Layer0"
      e.layer = newlayer
    end
  end
  @step.next!
end

#
#
#
def LDraw.import_test
  self.import("c:/ldraw/test.dat")
end

#
#
#
def LDraw.ex_im_test
  export
  import_test
end

#
#
#
def LDraw.make_part
end
class Sketchup::ComponentDefinition
  def to_dat
  end
end
#
#
#
def LDraw.com2dat
  puts "com2dat called."
  sel = Sketchup.active_model.selection[0]
  #if sel
  #if !sel.respond_to? "entities"
  #UI.messagebox("Please select something with entities.")
  #end
  #else
  #UI.messagebox("Please select a group or component.")
  #end
  if sel.typename == "ComponentInstance"
    cdef = sel.definition
    self.export(cdef.entities)
  end
  if sel.typename == "Group"
    self.export(sel.entities)
  end
  UI.messagebox("File exported to: #{@exfile}")
end

#
#
#
def LDraw.inlines2components(lines)
end
#
#
#
def LDraw.load_file
  @refs = {}
  file = "c:\\ldraw\\models\\sammy.mpd"
  file = UI.openpanel("Select file", "c:\\ldraw\\", "*.dat;*.ldr;*.mpd")
  parse_inlines(file)
  p @refs
  p @refs.keys
end
#
#
#
def LDraw.parse_inlines(file)
  name = nil
  gobble = false
  IO.readlines(file).each do |line|
    ary = line.split
    if ary[0] == "0"
      if ary[1] == "NOFILE"
	gobble = false
      end
    if ary[1] == "FILE"
      name = ary[2]
      @refs[name] = []
      gobble = true
    end
    end
    #if ary[0] == "1"
    #name = ary[-1]
    #@refs[name] = []
    #end

    if gobble
      @refs[name] << ary
    end
  end
end

#
#
#
def LDraw.bad_faces
  Sketchup.active_model.selection.clear
  faces = Sketchup.active_model.active_entities.select {|e| e.typename == "Face"}
  bad_faces = faces.select { |f| self.corner_vertices(f).length > 4 }
  UI.messagebox("Found #{bad_faces.length} bad faces.") unless bad_faces.empty?
  bad_faces.each { |bf|
    Sketchup.active_model.selection.add(bf) 
    #p = bf.parent
    #parent.entities.add_face(self.corner_vertives(bf))
    #bf.erase!
  }
end

#
#
#
def LDraw.swap_needed(ary)
  p1, p2, p3, p4 = ary
  n1 = (p1.vector_to p4) * (p1.vector_to p2).normalize
  n2 = (p2.vector_to p1) * (p2.vector_to p3).normalize
  n3 = (p3.vector_to p2) * (p3.vector_to p4).normalize
  n4 = (p4.vector_to p3) * (p4.vector_to p1).normalize
  return true if (dot = n1.dot n2) <= 0.0
  return true if (dot = n1.dot n3) <= 0.0
  return true if (dot = n1.dot n4) <= 0.0
  return true if (dot = n2.dot n3) <= 0.0
  return true if (dot = n2.dot n4) <= 0.0
  return true if (dot = n3.dot n4) <= 0.0
  return false
end
#
#
#
def LDraw.swap_points(ary, i, j)
  ary[j], ary[i] = ary[i], ary[j]
end
#
#
#
def LDraw.copy_translation
  s = Sketchup.active_model.selection[0]
  if( s.typename != "ComponentInstance" )
    UI.messagebox("Not an Instance")
  else
    @transformation = s.transformation
    p @transformation
  end
end
#
#
#
def LDraw.apply_translation
  s = Sketchup.active_model.selection[0]
  if( s.typename != "ComponentInstance" )
    UI.messagebox("Not an Instance")
  else
    s.transform! @axes_t
  end
end
#
#
#
def LDraw.show_transformation
  s = Sketchup.active_model.selection[0]
  if( s.typename != "ComponentInstance" )
    UI.messagebox("Not an Instance")
  else
    p s.definition.name
    p s.transformation.to_a
  end
end

def LDraw.triangulate_face(*faces)
  if faces.empty?
    face = Sketchup.active_model.selection[0]
  end
  entities=Sketchup.active_model.entities
  verts = self.corner_vertices(face).collect { |v| v.position.to_a }
  tv = triangulate verts
  entities.erase_entities face
  p tv
  tv.each { |tri|
    entities.add_face tri.collect {|ve| verts[ve]} 
  }
end

def LDraw.split_mpd(file)
  #file = "BusinessTurboPropPlane.mpd"
  #file = ARGV.shift.chomp
  files = {}
  in_file = false
  basename = nil
  IO.foreach(file) { |line|
    line.strip!
    ary = line.split
    if ary[1] == "FILE"
      filename =( @modeldir+ary[2] ).strip
      basename = File.basename(filename)
      if files[basename].nil?
	puts "creating key: #{basename}"
	files[basename] = []
	in_file = true
      else
	raise "File exists"
      end
    end
    if in_file
      files[basename].push(line)
    end
  }
  files.each do |k, contents|
    outname = @modeldir + "/" + k
    File.open(outname, "w") { |file| file.puts(contents) }
  end
end # split_mpd

def LDraw.create_layers
  Sketchup.active_model.start_operation("Create Layers", true)
  parts = {}
  ents = Sketchup.active_model.entities
  ents.each do |e|
    next unless e.is_a? Sketchup::ComponentInstance
    z = e.transformation.origin.z.round
    parts[z] ||= []
    parts[z].push(e)
  end
  keys = parts.keys.sort
  layers = Sketchup.active_model.layers
  step = "Step 01"
  keys.each do |k|
    layer = layers.add(step)
    step.next!
    parts[k].each do |e|
      e.layer = layer
    end
  end
  Sketchup.active_model.commit_operation
  parts.keys.sort.each {|k| puts "#{k}:#{parts[k].size}"}

end # getZ

def LDraw.create_pages
  Sketchup.active_model.start_operation("Create Pages", true)
  layers = Sketchup.active_model.layers
  pages = Sketchup.active_model.pages
  layers.each do |layer|
    next if layer.name == "Layer0"
    page = pages.add(layer.name)
    page.use_camera = false
  end
  Sketchup.active_model.commit_operation
end

def LDraw.rotate_part
  part = Sketchup.active_model.selection[0]
  o = part.transformation.origin
  part.transform!(Geom::Transformation.rotation(o, Z_AXIS, 90.degrees))
end

def LDraw.new_from_template
  old_template = Sketchup.template
  pf = Sketchup.find_support_file("Plugins")
  tfile = File.join(pf, "LDrawSystem", "template", "ldrawsystem.skp")
  Sketchup.template = tfile
  Sketchup.file_new
  Sketchup.template = old_template
end

def LDraw.start_positioner
  Sketchup.active_model.select_tool(JF_LDrawPositioner.new)
end

def LDraw.save(title = "")
  pf = Sketchup.find_support_file("Plugins")
  ld = File.join(pf, "LDrawSystem", "template")
  if title.empty?
    title = Sketchup.active_model.title
  end
  if title.empty?
    title = "Untitled.skp"
  end
  path = File.join(ld, title)
  Sketchup.active_model.save(path)
end
def LDraw.save_as_template
  save("LDrawSystem.skp")
end

def LDraw.import_e(file)
end



#
scriptname = File.basename(__FILE__)
unless file_loaded?(scriptname)

  menu = UI.menu.add_submenu("LDraw System")

  mymenu = true

  menu.add_item("New LDraw File") { LDraw.new_from_template }
  menu.add_separator
  menu.add_item("Export model") { LDraw.export_model }
  menu.add_separator

  menu.add_item("Import PN(s)") { LDraw.import_bynum }
  menu.add_item("Import file") { LDraw.import }
  menu.add_separator

  mv_menu = menu.add_submenu("Positioning")
  mv_menu.add_item("Positioner Tool") { LDraw.start_positioner }
  mv_menu.add_item("Rotate Part") { LDraw.rotate_part }

  menu.add_separator
  menu.add_item("Browse Model Dir") { LDraw.open_model_dir }
  menu.add_item("Configure") { LDraw.config }
  menu.add_item("About") { LDraw.about }

  if mymenu
    menu.add_separator
    menu.add_item("Export component to .dat") { LDraw.com2dat }
    menu.add_item("New Step") { LDraw.new_step }
    menu.add_item("Zoom All Pages") { LDraw.zoom_all_pages }
    menu.add_item("Stack Layers") { LDraw.layers_stack }
    menu.add_item("Seq Layers") { LDraw.layers_curr_prev }
    menu.add_item("Export All Images") { LDraw.write_all_pages }
    menu.add_item("Goto Scene 1") { LDraw.gotoScene(0) }
    menu.add_item("Create Layers") { LDraw.create_layers }
    menu.add_separator
    menu.add_item("Save as Template") { LDraw.save_as_template }

    # Debug sub menu
    debug = menu.add_submenu("Debug") {}
    debug.add_item("Show Bad Faces") { LDraw.bad_faces }
    debug.add_item("Triangulate Face") { LDraw.triangulate_face }
    debug.add_item("XRotate 90") {LDraw.rot_all(90)}
    debug.add_item("XRotate -90") {LDraw.rot_all(-90)}
    debug.add_item("Make STEPs") { LDraw.make_steps }
    debug.add_item("Import parts list ") { LDraw.import_partslist }
    debug.add_item("Load mpd") { LDraw.load_file }
    debug.add_item("Show Transformation") { LDraw.show_transformation }
    #debug.add_item("Copy Transformation") { LDraw.copy_translation }
    #debug.add_item("Apply Transformation") { LDraw.apply_translation }
  end

  file_loaded(scriptname)


end # end onLoad (do once)

##
#
# Experimental garbage
#
##




