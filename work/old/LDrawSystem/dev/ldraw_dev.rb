UI.menu.add_item("Go") { get_pn } unless @gomenu
@gomenu = true

def go(pn)
  puts "Go!"
  @lpath = "C:/ldraw/"
  file = path_to(pn)
  tr = Geom::Transformation.rotation(ORIGIN, X_AXIS, 90.degrees)
  #tr *= Geom::Transformation.axes(ORIGIN, X_AXIS, Z_AXIS.reverse, Y_AXIS)
  #tr = tr2 * tr1
  tr = Geom::Transformation.new
  entities = Sketchup.active_model.entities
  cdef = add_def(File.basename(file), '')
  Sketchup.active_model.start_operation "Import", true
  @studs_layer = Sketchup.active_model.layers.add("LD_Studs")
  @const_layer =  Sketchup.active_model.layers.add("LD_Const")
  Sketchup.active_model.rendering_options["FaceFrontColor"] = Sketchup::Color.new(242,235,189)
  read_file(file, cdef.entities, tr)
  ins = entities.add_instance cdef, [0,0,0]
  ins.transform! Geom::Transformation.new(ORIGIN, X_AXIS, -90.degrees)
  Sketchup.active_model.commit_operation
end

def get_pn
  ret = UI.inputbox(["Part No"])
  go ret[0]+".dat"
end

def get_file
  file = UI.openpanel("Model", "c:\\ldraw\\", "*.ldr")
  return unless file
end


def add_def(name, desc = "")
  if( cdef = Sketchup.active_model.definitions[name] )
    cdef.entities.clear!
    return cdef
  else
    cdef = Sketchup.active_model.definitions.add(name) 
    pt = cdef.entities.add_cpoint([0, 0, 0])
    pt.layer = @const_layer
    cdef.layer = @studs_layer if name[/stud/]
    return cdef
  end
end

def read_file(file, container, matrix)
  puts "reading file: #{file}"
  lines = IO.readlines(file)
  lines.each do |line|
    ary = line.split
    next if ary[0] == "0" or ary.empty?
    cmd = ary.shift
    color = ary.shift
    part_m = ary_to_trans(ary[0, 12])
    case cmd
    when "1" # File
      name = ary.pop
      raise "bad array" if ary.length != 12
      unless (part_def = Sketchup.active_model.definitions[name])
	part_def = add_def(name)
	read_file(path_to(name), part_def.entities, matrix)
      end
      part = container.add_instance(part_def, part_m)
      Cleanup.cleanup_model part.definition.entities
      ents = part.explode unless name[/stud/]
    when "3" # Triangle
      ary.map!{|e| e.to_f }
      pts = [ ary[0, 3], ary[3, 3], ary[6, 3] ]
      pts.map!{|e| Geom::Point3d.new(e)}
      pts.map!{|e| e.transform!(matrix)}
      begin
	face = container.add_face(pts)
      rescue => e
	p pts
      end
    when "4" # quad
      ary.map!{|e| e.to_f }
      pts = [ ary[0, 3], ary[3, 3], ary[6, 3], ary[9, 3] ]
      pts.map!{|e| Geom::Point3d.new(e)}
      pts.map!{|e| e.transform!(matrix)}
      begin
	container.add_face(pts)
      rescue => e
	p pts
      end
    end
  end
end


def path_to(name)
  if (File.exist?( path = File.join(@lpath, "models", name)))
    return path
  end
  if (File.exist?( path = File.join(@lpath, "parts", name)))
    return path
  end
  if (File.exist?(path = File.join(@lpath, "p", name)))
    return path
  end
end

def ary_to_trans(a)
  x,y,z,a,b,c,d,e,f,g,h,i = a
  r1 = [a, d, g, 0.0]
  r2 = [b, e, h, 0.0]
  r3 = [c, f, i, 0.0]
  r4 = [x, y, z, 1.0]
  #r1 = [a, b, c, 0.0]
  #r2 = [d, e, f, 0.0]
  #r3 = [g, h, i, 0.0]
  #r4 = [x, y, z, 1.0]
  na = r1 + r2 + r3 + r4
  na.map!{|e| e.to_f}
  #p na
  t = Geom::Transformation.new(na)
end

=begin

# ldraw.rb (C) 2006 jim.foltz@gmail.com
#
#
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
require 'inputbox'

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



module LDrawSystem

  # Various Global Options
  #
  @plugins_dir   = Sketchup.find_support_file("Plugins")
  @ldraw_sys_dir = File.join(@plugins_dir, "LDrawSystem")
  @ldview = %(c:\\Program Files\\LDView\\ldview.exe)

  @setlist_dir = File.join(@ldraw_sys_dir, "set_lists")
  @ldraw_export_dir = File.join(@ldraw_sys_dir, "exports")

  @use_skps = true # use Sketchup parts if available
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
  @skpdir = File.join(@plugins_dir, "LDrawSystem", "parts")
  @use_skps = Sketchup.read_default("LDraw", "use_skps")
  @use_skps = @use_skps == "true"

  # Skip components in this array. stud4 is a stud underneath bricks.
  #@exclude = ["stud4", "4-4edge", "2-4edge", "ring3", "stud3"]
  @exclude = ["4-4edge", "2-4edge"]

  # future use: mpd files.
  @files = {}

  @parts_list = Hash.new(0)
  # ===========================================
  $debug = false
  @i = 0
  @indent = 0
  Sketchup.send_action("showRubyPanel:") if $debug
  @newlayer = nil
  @step = "Step 01"
  @do_steps = false
  #@itr2 = Geom::Transformation.axes(ORIGIN, X_AXIS, Z_AXIS.reverse, Y_AXIS)
  #@itr = Geom::Transformation.rotation(ORIGIN, X_AXIS, -90.degrees)
  #@itr3 = Geom::Transformation.rotation(ORIGIN, X_AXIS, 90.degrees)
  #@itr4 =  @itr2 * @itr3
  #@itr2 = Geom::Transformation.rotation(ORIGIN, X_AXIS, 90.degrees)
  #@itr#.invert!
  #@itr = Geom::Transformation.new
  #tr2 = Geom::Transformation.axes(t.origin, t.xaxis, t.zaxis.reverse, t.yaxis)

  unless @inputbox
    @inputbox = Inputbox.new("LDrawSystem Configuration")
    #@inputbox.add "LDraw directory", @ldrawdir
    #@inputbox.add "Model directory", @modeldir
    #@inputbox.add "Use Skps", %w(Yes No), "Yes"
    @inputbox.add "SketchUp Parts Directory", @skpdir
  end

  @lcolors = {
    'red'          => [196, 0  , 38 , 0]  ,
    'white'        => [255, 255, 255, 0]  ,
    'blue'         => [0  , 51 , 178, 0]  ,
    'green'        => [0  , 140, 20 , 0]  ,
    'yellow'       => [255, 220, 0  , 0]  ,
    'black'        => [58 , 58 , 58 , 0]  ,
    'clear'        => [255, 255, 255, 128],
    'trltblue'     => [174, 239, 236, 128],
    'oldgray'      => [193, 194, 193, 0]  ,
    'oldgrey'      => [193, 194, 193, 0]  ,
    'tan'          => [232, 207, 161, 0]  ,
    'olddkgray'    => [99 , 95 , 82 , 0]  ,
    'olddkgrey'    => [99 , 95 , 82 , 0]  ,
    'trneonorange' => [249, 96 , 0  , 128],
    'chromesilver' => [224, 224, 224, 0]  ,
    'sandblue'     => [106, 122, 150, 0]
  }

end

def LDrawSystem.config
  # Read defaults
  ret = @inputbox.show
  return unless ret
  @ldrawdir = ret[0].gsub(/\\/, "/")
  @modeldir = ret[1].gsub(/\\/, "/")
  @ldrawdir += "/" unless @ldrawdir[-1] == 47
  @modeldir += "/" unless @modeldir[-1] == 47
  @use_skps = ret[2] == "Yes"

  # Save settings
  a = Sketchup.write_default("LDraw", "LDrawDir", @ldrawdir)
  b = Sketchup.write_default("LDraw", "ModelDir", @modeldir)
  b = Sketchup.write_default("LDraw", "use_skps", @use_skps.to_s)

  # =================
  # Display Settings
  # =================
  #Sketchup.send_action(10598) # enable transparency
end

def LDrawSystem.init
end




def LDrawSystem.rot_all(angle)
  # Rotate before export
  model = Sketchup.active_model
  entities = model.entities
  t = Geom::Transformation.rotation([0,0,0],[1,0,0],angle.degrees)
  status = entities.transform_entities t, entities.collect
end

def LDrawSystem.corner_vertices(face)
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


def LDrawSystem.about
  UI.openURL("http://sketchuptips.blogspot.com/2007/08/plugin-ldrawrb.html")
end

def LDrawSystem.open_model_dir
  UI.openURL(@modeldir)
end


def LDrawSystem.read_colors
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

def LDrawSystem.add_materials
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
def LDrawSystem.set_color(ent, code)
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

def LDrawSystem.add_part_in_model(pn)
  # Part is already in model
  if cdef = Sketchup.active_model.definitions[pn]
    return cdef
  end
  # Load from parts directory
  skpfile =File.join(@skpdir, "#{pn}.skp")
  if File.exist?(skpfile)
    if cdef = Sketchup.active_model.definitions.load(skpfile)
      return cdef
    end
  end
end

#
#
#
def LDrawSystem.importlast
  self.import(@file)
end

#
#
#
def LDrawSystem.import_bynum(pn=nil)
  if pn.nil?
    ret = UI.inputbox(["Number"], [], "Enter Part Number")
    return unless ret
    pn = ret[0].strip
  end
  raise "#{__LINE__}: part not String - #{pn.class}." unless pn.is_a? String
  file, r = get_path( pn )
  @file = file
  cdef = import(file) if file
  p cdef.class
  if cdef.is_a? Sketchup::ComponentDefinition
    return cdef
    #Sketchup.active_model.place_component cdef
  else
    puts "import_bynum: cdef is not a cdef:#{__LINE__}"
    return nil
  end
end

#
#
#
def LDrawSystem.import_partslist(file = nil)
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


def LDrawSystem.start_operation(name)
  Sketchup.active_model.start_operation(name, true)
end
def LDrawSystem.commit_operation
  Sketchup.active_model.commit_operation
end

############################################
#
# Passs in a file path. If nil, prompt for file
def LDrawSystem.import(file = nil)
  if file == false
    puts "#{__LINE__} file is false."
    return false
  end
  init()
  if file.nil?
    modeldir = @modeldir.gsub(/\//, "\\\\")
    file = UI.openpanel("Select a .dat File", modeldir, "*.dat;*.ldr")
    return unless file
    @do_steps = true
    insert = true
  end
  file.gsub!(/\\/, '/')
  split_mpd(file)
  puts "BEGIN #{file}"
  time1 = Time.now
  cname = File.basename(file)[0..-5]
  name = @step
  start_operation("Import")
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
  tr = Geom::Transformation.rotation(ORIGIN, X_AXIS, -90.degrees)
  Sketchup.active_model.entities.add_instance(cdef, tr) if insert
  commit_operation
  #UI.beep
  puts "Load time: #{Time.now - time1} seconds."
  cdef
end

def LDrawSystem.validity_check
  Sketchup.send_action 21124 # validity check
end


#
# Can acceppt an index, a Page object, and a Scene name
def LDrawSystem.gotoScene(o=0)
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
def LDrawSystem.layers_curr_prev # ladder
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

def LDrawSystem.layers_stack # additive
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

def LDrawSystem.getCurrScene()
  return Sketchup.active_model.pages.selected_page
end

# Sets camera to current view for all pages
# Does not set the zoom for all pages
# # TODO rename to a betyter name
def LDrawSystem.zoom_all_pages
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

def LDrawSystem.write_all_pages
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
def LDrawSystem.process_file(file, cdef, color)
  @indent += 1
  flag = false
  lines = IO.readlines(file)
  first_line = lines.shift.strip
  cdef.description = first_line[2..-1].to_s
  step = 1
  lines.each do |line|
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
	  @step.next!
	  name = @step
	  @newlayer = Sketchup.active_model.layers.add name
	end
      end

    when "1" # file reference
      color = ary.shift
      #p ary

      file = ary.pop
      cname = file[0..-5]
      if @exclude.include? cname
	puts "Ignoring request for #{cname}"
	next
      end
      ary.map!{|e| e.to_f}
      raise "#{__LINE__} - incorrect array elements." if ary.length != 12
      # Is component already in model?
      if( ndef = Sketchup.active_model.definitions[cname] and @use_skps )
	#dp "using already defined #{cname}."
      elsif( File.exist?(file = File.join(@skpdir, cname+".skp")) and @use_skps )
	ndef = Sketchup.active_model.definitions.load(file)
      else
	file, prim = get_path(cname)
	if file
	  ndef = Sketchup.active_model.definitions.add(cname)
	  dp "adding new def #{cname} #{ndef.inspect} "
	  process_file(file, ndef, color)
	else
	  puts "Can't find #{cname}.dat"
	  exit
	end
      end
      raise "#{__LINE__} - No definition" unless cdef
      t = array_to_transformation(ary)
      #t = mod_trans(t).inverse
      #t  *= @itr
      ins = cdef.entities.add_instance(ndef, t)
      if( (!@newlayer.nil?) and (! prim ) )
	ins.layer = @newlayer 
      end
      self.set_color(ins, color)

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
def LDrawSystem.array_to_transformation(ary)
  x,y,z,a,b,c,d,e,f,g,h,i = ary
  r1 = [a, d, g, 0.0]
  r2 = [b, e, h, 0.0]
  r3 = [c, f, i, 0.0]
  r4 = [x, y, z, 1.0]
  t = Geom::Transformation.new([r1, r2, r3, r4].flatten)
end

#################################################
#
#
def LDrawSystem.get_path(name)
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
def LDrawSystem.file2cname(file)
  #p file
  a = file.split('/')
  name = a[-2] + "/" + a[-1]
  #p name
end

#
#
#
def LDrawSystem.draw2(ary, cdef)
  dp "+Line to #{cdef.name}: #{ary.inspect}"
  color = ary.shift
  ary.map! { |e| e.to_f  }
  p1, p2 = ary.slice!(0, 3), ary
  edge = cdef.entities.add_edges(p1, p2)
end

#
#
#
def LDrawSystem.draw3(ary, cdef, color)
  dp "+Tri to #{cdef.name}: #{ary.inspect}"
  ary.map! {|e| e.to_f }
  pts = [ ary[0,3], ary[3,3], ary[6, 3] ]
  #pts.map!{|e| e.transform!(@itr)}
  face = cdef.entities.add_face( pts )
  self.set_color(face, color)
end

#
#
#
def LDrawSystem.draw4(ary, cdef, color)
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
  #pts.map!{|e| e.transform!(@itr)}

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
def LDrawSystem.draw5(ary, cdef)
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
def LDrawSystem.export(entities)
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

def LDrawSystem.face2line(face)
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
def LDrawSystem.export_model
  #path = "c:\\ldraw\\"
  read_colors unless @colors
  #path = @modeldir.gsub(/\//, "\\\\")
  title = Sketchup.active_model.title
  title = "Untitled" if title.empty?
  title += ".ldr"
  filename = UI.savepanel("Export model", @ldraw_export_dir, title)
  return unless filename
  ext = File.extname(filename)
  if ext.empty?
    filename += ".ldr"
  end
  #self.rot_all(90)
  #filename = path + "model.dat"
  fp = File.new(filename, "w")
  # Iterate Layers
  layers = Sketchup.active_model.layers
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
      #t = tt.to_a
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
  faces.each { |face| fp.puts face2line(face) }
  fp.flush
  fp.close
  #self.rot_all(-90)
  UI.beep
  r = UI.messagebox("View exported file in LDView?", MB_YESNO)
  if r == 6
    write_batch(filename)
  end

end

def LDrawSystem.mod_trans(t, d = 90)
  #return t
  #t = ins.transformation
  tr1 = Geom::Transformation.rotation(ORIGIN, X_AXIS, d.degrees)
  tr2 = Geom::Transformation.axes(t.origin, t.xaxis, t.zaxis.reverse, t.yaxis)
  #t2 = t * tr1 * tr2# * tr2
  t.set!(tr1 * tr2)
  return (t)
end


def LDrawSystem.write_batch(file)
  fov = Sketchup.active_model.active_view.camera.fov
  cmd =  %(@echo off\nstart "" "#{@ldview}" -FOV=#{fov} "#{file}")
  batch_file = File.join(@ldraw_sys_dir, "ldview.bat")
  File.open(batch_file, "w") { |f| f.puts cmd }
  UI.openURL(batch_file)
end


def LDrawSystem.new_step
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
def LDrawSystem.import_test
  self.import("c:/ldraw/test.dat")
end

#
#
#
def LDrawSystem.ex_im_test
  export
  import_test
end

#
#
#
def LDrawSystem.make_part
end
class Sketchup::ComponentDefinition
  def to_dat
  end
end
#
#
#
def LDrawSystem.com2dat
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
def LDrawSystem.inlines2components(lines)
end
#
#
#
def LDrawSystem.load_file
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
def LDrawSystem.parse_inlines(file)
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
def LDrawSystem.bad_faces
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
def LDrawSystem.swap_needed(ary)
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
def LDrawSystem.swap_points(ary, i, j)
  ary[j], ary[i] = ary[i], ary[j]
end
#
#
#
def LDrawSystem.copy_translation
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
def LDrawSystem.apply_translation
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
def LDrawSystem.show_transformation
  s = Sketchup.active_model.selection[0]
  if( s.typename != "ComponentInstance" )
    UI.messagebox("Not an Instance")
  else
    p s.definition.name
    p s.transformation.to_a
  end
end

def LDrawSystem.triangulate_face(*faces)
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

def LDrawSystem.split_mpd(file)
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

def LDrawSystem.create_layers
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

def LDrawSystem.create_pages
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

def LDrawSystem.rotate_part
  part = Sketchup.active_model.selection[0]
  o = part.transformation.origin
  part.transform!(Geom::Transformation.rotation(o, Z_AXIS, 90.degrees))
end

def LDrawSystem.new_from_template
  old_template = Sketchup.template
  tfile = File.join(@plugins_dir, "LDrawSystem", "template", "ldrawsystem.skp")
  Sketchup.template = tfile
  Sketchup.file_new
  Sketchup.template = old_template
end

def LDrawSystem.start_positioner
  Sketchup.active_model.select_tool(JF_LDrawPositioner.new)
end

def LDrawSystem.save(title = "")
  ld = File.join(@plugins_dir, "LDrawSystem", "template")
  if title.empty?
    title = Sketchup.active_model.title
  end
  if title.empty?
    title = "Untitled.skp"
  end
  path = File.join(ld, title)
  Sketchup.active_model.save(path)
end
def LDrawSystem.save_as_template
  save("LDrawSystem.skp")
end

def LDrawSystem.random_colors
  sel = Sketchup.active_model.selection
  return if sel.empty?
  mats = Sketchup.active_model.materials.to_a
  return if mats == []
  Sketchup.active_model.start_operation("Random Colors", true)
  sel.each do |e|
    next unless e.is_a? Sketchup::ComponentInstance
    e.material = mats[Integer(mats.size * rand)]
  end
  Sketchup.active_model.commit_operation
end

def LDrawSystem.listener(s)
  $str << s
  if s == "Connection established"
    puts "fetching #{$num}"
    SKSocket.write "GET /inv/sets/#{$num} HTTP/1.0\r\n\n"
  end
  if s == "Connection closed"
    SKSocket.disconnect
    puts "Done"
    # Do something useful with the data
    parse_inventory($str)
  end
end

def LDrawSystem.get_peeron_inventory
  unless Sketchup.is_online
    UI.messagebox("You do not appear to be online.")
    return
  end
  ret = UI.inputbox(["Enter Peeron Set #:"],[] ,[] , "Import Set Inventory")
  return unless ret
  if( File.exist?(File.join(@setlist_dir, ret[0]+".lst")))
    # read and prase setlist
  end

  $num = ret[0]
  $str = []
  SKSocket.connect "www.peeron.com", 80
  SKSocket.add_socket_listener {|e| listener(e)}
end

      def LDrawSystem.parse_inventory(page)
  #add_materials
  read_colors unless @colors
  re = %r(<a href="http://www.peeron.com/inv/parts/(.*)")
  parts = []
  page.each do  |line|
    part = line.scan( /^<td>(\d+)<.td>.*inv.parts.*?["']>(.*?)<............(.*?)<.td>/ ) #<\/td><td>(.*)<\/td>/ )
    unless part.empty?
      parts << part[0]
      p part
    end
  end
  tr = Geom::Transformation.rotation(ORIGIN, X_AXIS, -90.degrees)
  pt = [0,0,0]
  lastw  = 0
  parts.each_with_index do |part, i|
    q, n, color = part
    if cdef = import_bynum(n)
      w = cdef.bounds.width
      h = cdef.bounds.depth
      if pt.x > 700
	pt.x = 0
	pt.y += h + 160
      end
      pt.x = pt.x + (0.5 * lastw + 0.5 * w) + 20
      (q.to_i).times do 
	pt.z += cdef.bounds.height + 10
	tr1 = Geom::Transformation.new(pt)
	tr2 = mod_trans(tr1, 0)
	ins = Sketchup.active_model.entities.add_instance(cdef,tr2)
	mat = Sketchup.active_model.materials[ color ]
	unless mat
	  lcolor = @lcolors[color.downcase]
	  nc = Sketchup::Color.new(lcolor[0, 3])
	  mat = Sketchup.active_model.materials.add color
	  mat.color = nc
	  mat.alpha = (1 - lcolor[3]/255.0)
	end
	ins.material = mat
      end
      pt.z = 0
      lastw = w
    end
  end
end

def LDrawSystem.show_help
end



#
scriptname = File.basename(__FILE__)
unless file_loaded?(scriptname)

  menu = UI.menu.add_submenu("LDraw System")

  menu.add_item("Export Model to LDraw (.ldr)") { LDrawSystem.export_model }

  menu.add_item("Configure") { LDrawSystem.config }
  menu.add_item("Help") { LDrawSystem.show_help }

  mymenu = true

  if mymenu
    menu.add_item("About") { LDrawSystem.about }
    menu.add_item("Browse Model Dir") { LDrawSystem.open_model_dir }
    menu.add_item("Import .ldr file") { LDrawSystem.import }
    mv_menu = menu.add_submenu("Positioning")
    mv_menu.add_item("Positioner Tool") { LDrawSystem.start_positioner }
    mv_menu.add_item("Rotate Part") { LDrawSystem.rotate_part }
    menu.add_separator
    menu.add_separator
    menu.add_item("Import Peeron Inventory") { LDrawSystem.get_peeron_inventory }
    menu.add_item("New LDraw File") { LDrawSystem.new_from_template }
    menu.add_item("Import PN(s)") { LDrawSystem.import_bynum }
    menu.add_item("Export component to .dat") { LDrawSystem.com2dat }
    menu.add_item("New Step") { LDrawSystem.new_step }
    menu.add_item("Zoom All Pages") { LDrawSystem.zoom_all_pages }
    menu.add_item("Stack Layers") { LDrawSystem.layers_stack }
    menu.add_item("Seq Layers") { LDrawSystem.layers_curr_prev }
    menu.add_item("Export All Images") { LDrawSystem.write_all_pages }
    menu.add_item("Goto Scene 1") { LDrawSystem.gotoScene(0) }
    menu.add_item("Create Layers") { LDrawSystem.create_layers }
    menu.add_item("Create Pages") { LDrawSystem.create_pages }
    menu.add_item("Save as Template") { LDrawSystem.save_as_template }
    menu.add_item("Random Colors") { LDrawSystem.random_colors }

    # Debug sub menu
    debug = menu.add_submenu("Proto") {}
    debug.add_item("Show Bad Faces") { LDrawSystem.bad_faces }
    debug.add_item("Triangulate Face") { LDrawSystem.triangulate_face }
    debug.add_item("XRotate 90") {LDrawSystem.rot_all(90)}
    debug.add_item("XRotate -90") {LDrawSystem.rot_all(-90)}
    debug.add_item("Import parts list ") { LDrawSystem.import_partslist }
    debug.add_item("Load mpd") { LDrawSystem.load_file }
    debug.add_item("Show Transformation") { LDrawSystem.show_transformation }
    #debug.add_item("Copy Transformation") { LDrawSystem.copy_translation }
    #debug.add_item("Apply Transformation") { LDrawSystem.apply_translation }
  end

  file_loaded(scriptname)


end # end onLoad (do once)

##
#
# Experimental garbage
#
##




=end
