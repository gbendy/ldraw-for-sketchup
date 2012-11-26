require 'sketchup'
require 'cleanup_model'

module LDrawPartImport
  @explodees = []
  @use_skps = true
end

unless file_loaded?("ldraw_part_importer.rb")
  menu = UI.menu("Plugins").add_submenu("LDraw Part Author") 
  menu.add_item("Import by PN") { LDrawPartImport.get_pn(true) }
  menu.add_item("Import by PN (no skps)") { LDrawPartImport.get_pn(false) }
  menu.add_item("Explode Non-Studs") { LDrawPartImport.do_explode }
  menu.add_item("Set Final View") { LDrawPartImport.set_view }
  file_loaded("ldraw_part_importer.rb")
end

def LDrawPartImport.go(pn)
  puts "Go!"
  file = path_to(pn)
  if file.nil?
    UI.messagebox("No part: #{pn}")
    return
  end
  entities = Sketchup.active_model.entities
  cdef = add_def(File.basename(file), '')
  Sketchup.active_model.start_operation "Import", true
  tr = Geom::Transformation.new
  #tr = Geom::Transformation.new(ORIGIN, X_AXIS, -90.degrees)
  if cdef.entities.length <= 1
    read_file(file, cdef.entities, tr)
  end
  ins = entities.add_instance cdef, [0,0,0]
  ins.transform! Geom::Transformation.new(ORIGIN, X_AXIS, -90.degrees)
  Sketchup.active_model.commit_operation
end

def LDrawPartImport.get_pn(f)
  @skp_path = "d:/sketchup/models/ldraw"
  @studs_layer = Sketchup.active_model.layers.add("LDraw_Studs")
  @const_layer =  Sketchup.active_model.layers.add("LDraw_Const")
  @lpath = "C:/ldraw/"
  @explodees = []
  ret = UI.inputbox(["Part No"])
  @part_no = ret[0]+".dat"
  @use_skps = f
  go ret[0]+".dat"
end

def get_file
  file = UI.openpanel("Model", "c:\\ldraw\\", "*.ldr")
  return unless file
end


#
# Look in model, then on disk, than make new new
def LDrawPartImport.add_def(name, desc = "")
  name = name.split('.')[0]
  raise "#{__LINE__} - bad name." if name.empty? or name.nil?
  print  name
  print " "
  if( cdef = Sketchup.active_model.definitions[name] )
    #cdef.entities.clear!
    #pt = cdef.entities.add_cpoint([0, 0, 0])
    #pt.layer = @const_layer
    puts "inmodel: #{cdef.entities.length}"
    return cdef
  elsif ( File.exist?(file = File.join(@skp_path, "p",  name+".skp")) and @use_skps )
    cdef = Sketchup.active_model.definitions.load(file)
    cdef.layer = @studs_layer if name[/stud/i]
    puts "#{file}: #{cdef.entities.length}"
    return cdef
  elsif ( File.exist?(file = File.join(@skp_path, name+".skp")) and @use_skps)
    cdef = Sketchup.active_model.definitions.load(file)
    cdef.layer = @studs_layer if name[/stud/i]
    puts "#{file}: #{cdef.entities.length}"
    return cdef
  else
    cdef = Sketchup.active_model.definitions.add(name) 
    pt = cdef.entities.add_cpoint([0, 0, 0])
    pt.layer = @const_layer
    cdef.layer = @studs_layer if name[/stud/i]
    puts "new def: #{cdef.entities.length}"
    return cdef
  end
end

def LDrawPartImport.fix_desc(desc)
  desc.gsub!(/^\s*0\s/, '')
  desc.strip!
  return desc
end

def LDrawPartImport.read_file(file, container, matrix)
  lines = IO.readlines(file)
  lines.each_with_index do |line, i|
    if i == 0
      desc = line
      puts "Description: #{desc}"
    else
      desc = ""
    end
    if File.basename(file) == @part_no and i == 0
      puts "-" * 10
      p file
      p @part_no
      puts "Setting description."
      Sketchup.active_model.description = fix_desc(desc)
    end
    ary = line.split
    next if ary[0] == "0" or ary.empty?
    cmd = ary.shift
    color = ary.shift
    part_m = ary_to_trans(ary[0, 12])
    case cmd
    when "1" # File
      name = ary.pop
      next if name[/edge/i]
      raise "bad array" if ary.length != 12
      part_def = add_def(name)
      part_def.description = desc if i == 0
      if part_def.entities.length <= 1
	read_file(path_to(name), part_def.entities, matrix)
      end
      part = container.add_instance(part_def, part_m)
      #Cleanup.cleanup_model part.definition.entities
      #ents = part.explode unless name[/stud/]
      @explodees << part unless name[/stud/i]
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
      LDrawSystem.set_color(face, color)
    when "4" # quad
      ary.map!{|e| e.to_f }
      pts = [ ary[0, 3], ary[3, 3], ary[6, 3], ary[9, 3] ]
      pts.map!{|e| Geom::Point3d.new(e)}
      pts.map!{|e| e.transform!(matrix)}
      p1, p2, p3, p4 = pts
      if swap_needed(pts)
	if( !swap_needed([p1, p2, p4, p3]) )
	  swap_points(pts, 2, 3)
	elsif( !swap_needed([p1, p3, p2, p4]) )
	  swap_points(pts, 1, 2)
	end
      end

      begin
	face = container.add_face(pts)
      rescue => e
	p pts
      end
      LDrawSystem.set_color(face, color)
    end
  end
end
def LDrawPartImport.path_to(name)
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



def LDrawPartImport.ary_to_trans(a)
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

def LDrawPartImport.purge
  Sketchup.active_model.definitions.purge_unused
  Sketchup.active_model.layers.purge_unused
  Sketchup.active_model.materials.purge_unused
  Sketchup.active_model.styles.purge_unused
end
def LDrawPartImport.set_view
  Sketchup.active_model.rendering_options["FaceFrontColor"] = Sketchup::Color.new(242,235,189)
  Sketchup.active_model.active_view.camera.perspective = false
  @const_layer.visible = false if @const_layer
  Sketchup.send_action("viewTop:")
  Sketchup.send_action("viewIso:")
  Sketchup.send_action("viewZoomExtents:")
  #Cleanup.cleanup_model Sketchup.active_model.active_entities
  if ( UI.messagebox("Purge?", MB_YESNO) == 6)
    purge
  end
end

  def LDrawPartImport.do_explode
    @explodees.each { |e| e.explode }
  end

def LDrawPartImport.swap_needed(ary)
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
def LDrawPartImport.swap_points(ary, i, j)
  ary[j], ary[i] = ary[i], ary[j]
end

  

class LDrawFile
  def initialize(name)
    @name = name
  end
  def read
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
end

