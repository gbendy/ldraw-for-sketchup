# ldraw.rb - ldraw file importer  Copyright (C) 2006 jim.foltz@gmail.com
#   Imports ldraw.org file formats .ldr and .dat
#   Adds LDraw sub menu under the Plugins menu
#
#   Does not support mpd files yet, but you might get lucky.
#
# LDraw is a file format for definging LEGO parts and models.
# http://www.ldraw.org
#
# Bug reports and feature requests to: jim.foltz@gmail.com
#
# TODO
#   * support transparency for colors (Window -> Display Settings -> Enable transparency)
#   * add materials only as needed
#   * support for colors 16 and 24
#   * handle optional lines (line type 5)
#   * export parts list/order form (p/n, qty, desc)
#   * export .dat, .ldr, or .mpd file? Not soon...
#   * add page for each STEP?
#
# DONE
#
# HISTORY
# 2006-10-19 - jf
#   v1.2
#   * added support to exclude files (bottom studs, for example)
#   * added lots of debugging output - slows things down
#   * use components in @ldrawdir/sketchup if they exist
#    
# 2006-10-18 - jim.foltz@gmail.com
#   v1.1
#   *  added menu option to Browse Model Directory
#   *  always open Ruby Panel 
#
# 06-10-18 - jim.foltz@gmail.com
#   v1.0
#   *  Added configuration option to menu.
#
#


module LDraw

   # ===========================================
   # Various Global Options
   #
   # not used yet
   # for debugging output nesting
   @indent = 0

   # Skip components in this array. stud4 is a stud underneath bricks.
   @exclude = ["stud4"]

   # future use: mpd files.
   @files = {}

   @parts_list = Hash.new(0)
   # ===========================================

   def self.about
      UI.openURL("http://jim.foltz.googlepages.com/sketchupldrawimporter")
   end

   def self.open_model_dir
      UI.openURL(@modeldir)
   end

   def LDraw::config
      @ldrawdir = @ldrawdir || "C:\\LDraw\\"
      @modeldir = @modeldir || "C:\\LDraw\\Models\\"
      ret = UI.inputbox(["LDraw dir", "Model dir"], [ @ldrawdir ,  @modeldir ], "Configure LDraw Importer")
      return unless ret
      @ldrawdir = ret[0]
      @modeldir = ret[1]

      # =================
      # Display Settings
      # =================
      #Sketchup.send_action(10598) # enable transparency

      # read colors
      @colors = {}
      IO.foreach("#{@ldrawdir}/ldconfig.ldr") do |line|
	 ary = line.split
	 next unless ary[1] == "!COLOUR"
	 code = ary[4].strip
	 @colors[code] = ary
      end
      p @colors.keys.sort
   end

   def LDraw.set_color(ent, code)
      return if code == "16" or code == "24"
      ary = @colors[code]
      return unless ary
      p code
      p ary
      name = ary[2]
      if mat = Sketchup.active_model.materials[name]
	 ent.material = mat
      else
	 mat = Sketchup.active_model.materials.add name
	 alpha = ary[10]
	 alpha = (alpha ? alpha.to_i : 255) / 255.0
	 mat.color = Sketchup::Color.new(ary[6])
	 mat.alpha = alpha 
	 ent.material = mat
      end
   end

   def self.importlast
      self.import(@file)
   end

   def LDraw::import(file = nil)
      Sketchup.send_action("showRubyPanel:")
      unless @ldrawdir
	 LDraw.config
      end
      if file.nil?
	 file = UI.openpanel("Select a .dat File",@modeldir, "*.dat;*.mpd;*.ldr")
	 return unless file
      end
      cname = File.basename(file)[0..-5]
      @file = file

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
      #t = Geom::Transformation.new
      Sketchup.active_model.entities.add_instance(cdef, t)
      UI.beep
      p @parts_list
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
	       #p fname
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
	    cname = file[0..-5]
	    if @exclude.include? cname
	       puts "Ignoring request for #{cname}"
	       next
	    end
	    ary.map!{|e| e.to_l}
	    x,y,z,a,b,c,d,e,f,g,h,i = ary
	    l1 = [a, d, g, 0]
	    l2 = [b, e, h, 0]
	    l3 = [c, f, i, 0]
	    l4 = [x, y, z, 1]
	    a = [l1, l2, l3, l4].flatten
	    t = Geom::Transformation.new(a)
	    # Is component already in model?
	    if ndef = Sketchup.active_model.definitions[cname]
	       puts "Adding from component browser: #{cname}"
	       # Add component to top-level cdef
	       # using transformation matrix
	       ins = cdef.entities.add_instance(ndef, t)
	       LDraw.set_color(ins, color)
	    elsif File.exist?(f4 = @ldrawdir + "/sketchup/" + cname + ".skp")
	       puts "Loading .skp from: #{f4}"
	       ndef = Sketchup.active_model.definitions.load(f4)
	       ins = cdef.entities.add_instance(ndef, t)
	       LDraw.set_color(ins, color)

	    else
	       # Add new component to active model, then
	       #ndef = Sketchup.active_model.definitions.add(cname)
	       #ndef.description = desc
	       # add instance to top-level cdef using matrix
	       f1 = @ldrawdir + "/p/" + cname + ".dat"
	       f2 = @ldrawdir + "/parts/" + cname + ".dat"
	       f3 = "./" + cname + ".dat"
	       file = nil
	       if File.exists? f1
		  file = f1
	       elsif File.exists? f2
		  file = f2
	       elsif File.exists? f3
		  file = f3
	       else
		  puts "CAN\'T FIND #{cname}!"
	       end
	       if file
		  ndef = Sketchup.active_model.definitions.add(cname)
		  process_file(file, ndef, color)
	       else
		  puts "Could't add #{cname}"
		  return
	       end

	       #p ndef
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
	    ary.map! { |e| e.to_l }
	    p1 = ary[0, 3]
	    p2 = ary[3, 3]
	    p3 = ary[6, 3]
	    p4 = ary[9, 3]

	    pts = [ p1, p2, p3, p4 ]
	    begin
	       face = cdef.entities.add_face( pts )
	    rescue => e
	       p e
	       p cname
	       p pts
	       #g = cdef.entities.add_group
	       #g.name = cname
	       #pts.each_with_index do |point, i|
	       #g.entities.add_cpoint(point)
	       #g.entities.add_text(i.to_s, point)
	       #end
	       #g.entities.add_edges(p1, p2)
	       #g.entities.add_edges(p2, p3)
	       #g.entities.add_edges(p3, p4)
	       #g.entities.add_edges(p4, p1)
	       # If we end up here it's usually because
	       # points are not co-planar. Could this be a rounding error
	       # or something similar? Maybe a scale issue.
	       f1 = cdef.entities.add_face( p1, p2, p4 )
	       f2 = cdef.entities.add_face( p3, p2, p4 )
	       e = f1.edges & f2.edges
	       p e
	       e[0].soft = true
	    end
	 when "5" # optional line
	    next
	    c = ary.shift
	    ary.map! { |e| e.to_l }
	    p1 = ary[0, 3]
	    p2 = ary[3, 3]
	    #p3 = ary[6, 3]
	    #p4 = ary[9, 3]
	    cdef.entities.add_cline(p1, p2)
	 end
      end
   end

end

scriptname = File.basename(__FILE__)

unless file_loaded?(scriptname)
   scriptname[/_v(.*)\.rb/]
   v = $1
   menu = UI.menu.add_submenu("LDraw v#{v}")
   menu.add_item("Import model") { LDraw.import }
   menu.add_item("Import last") { LDraw.importlast }
   menu.add_item("Configure") { LDraw.config }
   menu.add_item("Browse Model Dir") { LDraw.open_model_dir }
   menu.add_item("About LDraw Importer") { LDraw.about }
   file_loaded(scriptname)
end
