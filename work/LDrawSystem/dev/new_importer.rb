require 'sketchup'
require 'purgeall'
require 'cleanup_model'

unless file_loaded?("ldraw_part_importer.rb")
  UI.menu.add_item("Get PN") { MOD.get_pn } unless @gomenu
  UI.menu.add_item("Set View") { set_view } unless @gomenu
  UI.menu.add_item("Explode") { do_explode } unless @gomenu
  file_loaded "ldraw_part_importer.rb"
end

module MOD
end


def MOD.go(pn)
  puts "Go!"
  file = path_to(pn)
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

def MOD.get_pn()
  @skp_path = "d:/sketchup/models/ldrawsystem"
  @studs_layer = Sketchup.active_model.layers.add("LDraw_Studs")
  @const_layer =  Sketchup.active_model.layers.add("LDraw_Const")
  @lpath = "C:/ldraw/"
  @explodees = []
  ret = UI.inputbox(["Part No"])
  @part_no = ret[0]+".dat"
  go ret[0]+".dat"
end

def get_file
  file = UI.openpanel("Model", "c:\\ldraw\\", "*.ldr")
  return unless file
end


#
# Look in model, then on disk, than make new new
def MOD.add_def(name, desc = "")
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
  elsif ( File.exist?(file = File.join(@skp_path, "p",  name+".skp")) )
    cdef = Sketchup.active_model.definitions.load(file)
    cdef.layer = @studs_layer if name[/stud/i]
    puts "#{file}: #{cdef.entities.length}"
    return cdef
  elsif ( File.exist?(file = File.join(@skp_path, name+".skp")) )
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

def MOD.fix_desc(desc)
  desc.gsub!(/^\s*0\s/, '')
  desc.strip!
  return desc
end

def MOD.read_file(file, container, matrix)
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
      Cleanup.cleanup_model part.definition.entities
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
def MOD.path_to(name)
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



def MOD.ary_to_trans(a)
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

def MOD.set_view
  Sketchup.active_model.rendering_options["FaceFrontColor"] = Sketchup::Color.new(242,235,189)
  Sketchup.active_model.active_view.camera.perspective = false
  @const_layer.visible = false
  Sketchup.send_action("viewTop:")
  Sketchup.send_action("viewIso:")
  Sketchup.send_action("viewZoomExtents:")
  Cleanup.cleanup_model Sketchup.active_model.active_entities
  if ( UI.messagebox("Purge?", MB_YESNO) == 6)
    puts "purging..."
    PurgeAll.do(false)
    end
  end

  def MOD.do_explode
    @explodees.each { |e| e.explode }
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

