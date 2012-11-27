# ldraw - lraw importer
# Copyright (C) 2006 jim.foltz@gmail.com
#
# Adds LDraw sub menu under the Plugins menu
# Does not support mpd files yet, but you can try,
#
#2006-10-18
#  v1.1
#    added menu option to Browse Model Directory
#    always open Ruby Panel 
#
# 06-10-18 - v1.0
#    Added configuration option to menu.
#

scriptname = File.basename(__FILE__)
scriptname[/_v(.*)\.rb/]
v = $1

module LDraw

   def self.about
      UI.openURL("http://jim.foltz.googlepages.com/sketchupldrawimporter")
   end
   @files = {}

   def self.openmodeldir
	   UI.openURL(@modeldir)
   end


   def LDraw::config
      default = @ldrawdir
      default = "C:\\LDraw\\" unless default
      @modeldir = @modeldir || "C:\\LDraw\\Models\\"
      ret = UI.inputbox(["LDraw dir", "Model dir"], [default, @modeldir], "Configure LDraw Importer")
      return unless ret
      @ldrawdir = ret[0]
      @modeldir = ret[1]

      # read @colors
      @color = {}
      @alpha = {}
      IO.foreach("#{@ldrawdir}/ldconfig.ldr") do |line|
	 ary = line.split
	 next unless ary[1] == "!COLOUR"
	 code = ary[4].strip
	 #@color[code] = ary[6]
	 @color[code] = Sketchup::Color.new(ary[6])
	 line[/ALPHA (\d+) /]
	 alpha = $1 ? $1.to_i : 255
	 #@color[code][0].alpha = alpha
	 @color[code].alpha = alpha
	 @alpha[code] = alpha
      end
   end

   def LDraw.set_color(ent, col)
      ent.material = @color[col]
      #ent.material.alpha = @alpha[col] unless ent.material.nil?
   end


   def LDraw::import
      Sketchup.send_action("showRubyPanel:")
      unless @ldrawdir
	 LDraw.config
      end
      # dir is the parent directory of the p and parts directories
      #dir = "c:\\LDraw\\" 
      file = UI.openpanel("Select a .dat File",@modeldir, "*.dat;*.mpd;*.ldr")
      return unless file
      cname = File.basename(file)[0..-5]

      # Create a new component named after the model's filename
      cdef = Sketchup.active_model.definitions[cname]
      if cdef
	 UI.messagebox("Component #{cname} exists.")
	 cdef.erase!
      else
	 cdef = Sketchup.active_model.definitions.add(cname)
      end
      process_file(file, cdef)

      pt = [0,0,0]
      v = Geom::Vector3d.new(1, 0, 0)
      angle = -90.degrees
      t = Geom::Transformation.rotation(pt, v, angle)
      Sketchup.active_model.entities.add_instance(cdef, t)
   end

   def LDraw::process_file(file, cdef, color = "16")
      flag = false
      puts "processing: #{file}"
      cname = cdef.name
      lines = IO.readlines(file)
      first_line = lines.shift.strip
      cdef.description = first_line[2..-1].to_s
      #lines.each do |line|
      for line in lines
	 line.strip!
	 next if line.length == 0
	 ary = line.split
	 cmd = ary.shift

	 case cmd

	 when "0" # Comment/META
	    if ary[0] == "FILE"
	       puts "comment=#{line}"
	       fname = ary[1]
	       p fname
	       if @files.has_key? fname
		  puts "has key"
		  process_file(@files[fname], cdef)
	       else
		  flag == true
	       end
	    end

	 when "1" # file reference
	    color = ary.shift
	    file = ary.pop
	    ary.map!{|e| e.to_l}
	    x,y,z,a,b,c,d,e,f,g,h,i = ary
	    l1 = [a, d, g, 0]
	    l2 = [b, e, h, 0]
	    l3 = [c, f, i, 0]
	    l4 = [x, y, z, 1]
	    a = [l1, l2, l3, l4].flatten
	    t = Geom::Transformation.new(a)
	    cname = file[0..-5]
	    # Is component already in model?
	    if ndef = Sketchup.active_model.definitions[cname]
	       # Add component to top-level cdef
	       # using transformation matrix
	       ins = cdef.entities.add_instance(ndef, t)
	       LDraw.set_color(ins, color)
	    else
	       # Add new component to active model, then
	       ndef = Sketchup.active_model.definitions.add(cname)
	       #ndef.description = desc
	       # add instance to top-level cdef using matrix
	       f1 = @ldrawdir + "/p/" + cname + ".dat"
	       f2 = @ldrawdir + "/parts/" + cname + ".dat"
	       f3 = "./" + cname + ".dat"
	       if File.exists? f1
		  file = f1
	       elsif File.exists? f2
		  file = f2
	       elsif File.exists? f3
		  file = f3
	       else
		  puts "CAN\'T FIND #{cname}!"
	       end

	       process_file(file, ndef, color)
	       ins = cdef.entities.add_instance(ndef, t)
	       LDraw.set_color(ins, color)
	    end

	 when "2" # line between 2 points
	    color = ary.shift
	    ary.map! { |e| e.to_l  }
	    p1, p2 = ary.slice!(0, 3), ary
	    edge = cdef.entities.add_edges(p1, p2)
	    #LDraw.set_color(edge[0], color)

	 when "3" # filled triangle between 3 points
	    color = ary.shift
	    ary.map! {|e| e.to_l }
	    face = cdef.entities.add_face( ary[0,3], ary[3,3], ary[6, 3])
	    #face.edges.each {|e| LDraw.set_color(e, color) }

	 when "4" # filled quad between 4 points
	    color = ary.shift
	    x1,y1,z1, x2, y2, z2, x3, y3, z3, x4, y4, z4 = ary.map {|e| e.to_l }
	    p1 = [x1, y1, z1]
	    p2 = [x2, y2, z2]
	    p3 = [x3, y3, z3]
	    p4 = [x4, y4, z4]
	    pts = [ p1, p2, p3, p4 ]
	    #pts.each { |p| entities.add_cpoint(p) }
	    begin
	       face = cdef.entities.add_face( pts )
	       #face.edges.each { |e| e.material = @color[color] }
	       #face.edges.each {|e| LDraw.set_color(e, color) }
	    rescue => e
	       # If we end up here it's usually because
	       # points are not co-planar. Could this be a rounding error
	       # or something similar?
	       f1 = cdef.entities.add_face( p1, p2, p4 )
	       f2 = cdef.entities.add_face( p3, p2, p4 )
	    end
	 when "5" # optional line
	    c= ary.shift
	    x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4 = ary.map{|e|e.to_l }
	    p1 = [x1, y1, z1]
	    p2 = [x2, y2, z2]
	    cdef.entities.add_edges(p1, p2)
	 end
      end
   end

end




unless file_loaded?(scriptname)
   menu = UI.menu.add_submenu("LDraw v#{v}")
   menu.add_item("Import model") { LDraw.import }
   menu.add_item("Configure") { LDraw.config }
   menu.add_item("Browse Model Dir") { LDraw.openmodeldir }
   menu.add_item("About LDraw Importer") { LDraw.about }
   file_loaded(scriptname)
end
