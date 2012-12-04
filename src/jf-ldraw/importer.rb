# dat_importer.rb Copyright (c) 2009 jim.foltz@gmail.com
#
require 'sketchup'


module JF
  module LDraw

    def self.init
      @partsdir = 'c:/Users/Jim/LDraw/SketchUp'
      @lost_parts = Set.new
      parse_colors()
      @errors = []
      @base_dir = ''
    end

    def self.ui_import_part_by_number()
      init()
      @last_pn = "3001" unless @last_pn
      ret = UI.inputbox(["Part No"], [@last_pn], "Import DAT")
      if ret == false
        Sketchup.status_text = "Canceled."
        return
      end
      @last_pn = ret[0]
      part_no = full_path_to(ret[0]+".dat")
      cdef = import_definitions part_no
      return if cdef.nil?
      pass2 part_no
      ins = Sketchup.active_model.entities.add_instance(
        cdef,
        Geom::Transformation.rotation(ORIGIN, X_AXIS, -90.degrees)
      )
      Sketchup.active_model.active_view.zoom(ins)
      return ret[0]
    end

    
    # Allow user to browse for a file.
    # @return String<filepath> or nil
    def self.ui_file_browse
      init()
      file = UI.openpanel("Model", @opts[:model_import_dir], '*.*' )
      return unless file
      #pass1(file)
      @base_dir = File.dirname(file)
      cdef = import_definitions(file)
      if @lost_parts.length > 0
        puts "Missing parts:\n#{@lost_parts.to_a.sort.join(', ')}"
      end
      pass2(file)
      Sketchup.active_model.active_view.zoom_extents
      make_steps
      if @errors.length > 1
        UI.messagebox(@errors.join("\n"))
      end
    end

    # @param [String] pn - LDraw part number including .dat extention
    # Imports parts into Definitions, not into mode
    def self.import_definitions(file)
      init()
      file = full_path_to(file)
      if file.nil?
        UI.messagebox("No part: #{file}")
        return
      end
      Sketchup.active_model.definitions.purge_unused
      name = File.basename(file, '.dat')
      cdef = get_or_add_definition(name)

      if cdef.entities.length < 1
        Sketchup.active_model.start_operation "Import", true
        tr = Geom::Transformation.new
        entities = cdef.entities
        parse_file(file, entities, tr)
        #ins = Sketchup.active_model.entities.add_instance(cdef, tr)
        Sketchup.active_model.commit_operation
      end
      return cdef
    end # import_definitions

    def self.get_or_add_definition(name, desc = "")
      name = name.split('.')[0]
      if((cdef = Sketchup.active_model.definitions[name]))
        return cdef
      elsif File.exists?( f = File.join(@opts[:su_models_dir], name+'.skp') )
        cdef = Sketchup.active_model.definitions.load(f)
        return cdef
      else
        cdef = Sketchup.active_model.definitions.add(name) 
        return cdef
      end
    end

    def self.pass2(file)
      tr = Geom::Transformation.rotation(ORIGIN, X_AXIS, -90.degrees)
      layer = Sketchup.active_model.layers.add 'STEP 01'
      IO.readlines(file).each do |line|
        line.strip!
        ary = line.split
        cmd = ary.shift.to_i
        if cmd == 0 and ary[0] == 'STEP'
          layer = Sketchup.active_model.layers.add(Sketchup.active_model.layers[-1].name.next)
        end

        next unless cmd == 1
        color = ary.shift
        t_ary = []
        12.times { t_ary << ary.shift}
        ttr = ary_to_trans(t_ary)
        name = ary.pop
        name = File.basename(name, '.*')
        cdef = Sketchup.active_model.definitions[name]
        next if cdef.nil?
        ins = Sketchup.active_model.entities.add_instance(cdef, tr * ttr)
        ins.material = get_or_add_material(color)
        ins.layer = layer
      end
    end

    def self.parse_file(file, container, matrix, color='16')
      lines = IO.readlines(file)
      lines.each_with_index do |line, i|
        line.strip!
        next if line.empty? or line == '0'
        ary = line.split
        throwaay = ary.shift
        cmd, rest = first_rest(line)
        cmd = cmd.to_i

        case cmd

        when CMD_COMMENT

        when CMD_LINE
          this_color = ary.shift.strip
          # Do nothing

        when CMD_FILE
          #this_color = ary.shift.strip
          this_color, rest = first_rest(rest)
          if this_color.nil?
            p line
            fail
          end
          m = []
          12.times do
            elem, rest = first_rest(rest)
            m << elem.to_f
          end
          fail if m.length != 12

          name = (ary.pop).downcase
          name = rest.strip
          part_def = get_or_add_definition(name)
          if part_def.entities.length <= 1
            path = full_path_to(name)
            if path.nil?
              @lost_parts.insert(name)
            else
              parse_file(path, part_def.entities, matrix)
            end
          end
          part_m = ary_to_trans(m)
          part = container.add_instance(part_def, part_m)
          part.material = get_or_add_material(this_color)

        when CMD_TRI
          this_color = ary.shift.strip
          ary.map!{|e| e.to_f }
          pts = [ ary[0, 3], ary[3, 3], ary[6, 3] ]
          pts.map!{|e| Geom::Point3d.new(e)}
          pts.map!{|e| e.transform!(matrix)}
          mesh = Geom::PolygonMesh.new
          mesh.add_polygon(pts)
          container.add_faces_from_mesh(
            mesh, SMOOTH_ONLY, get_or_add_material(this_color)
          )

        when CMD_QUAD
          this_color = ary.shift.strip
          ary.map!{|e| e.to_f }
          pts = [ ary[0..2], ary[3..5], ary[6..8], ary[9..11] ]
          p1, p2, p3, p4 = pts
          if swap_needed(pts)
            if( !swap_needed([p1, p2, p4, p3]) )
              swap_points(pts, 2, 3)
            elsif( !swap_needed([p1, p3, p2, p4]) )
              swap_points(pts, 1, 2)
            end
          end
          mesh = Geom::PolygonMesh.new
          mesh.add_polygon(pts)
          container.add_faces_from_mesh(
            mesh, SMOOTH_ONLY, get_or_add_material(this_color)
          )
        end
      end
    end

    def self.first_rest(line)
      i = line.index(/\s/)
      l = line.length
      [line.slice(0, i), line.slice(i, l).strip]
    end

    def self.full_path_to(name)
      #puts "looking for: #{name}"
      if File.exist?( name )
        return name
      elsif (File.exist?(f = File.join(@base_dir, name)))
        return f
      elsif (File.exist?( path = File.join(@opts[:ldraw_dir], 'parts', name)))
        return path
      elsif (File.exist?(path = File.join(@opts[:ldraw_dir], 'p', name)))
        return path
      elsif (File.exist?(path = File.join(@opts[:ldraw_dir], 'parts/s', name)))
        return path
      else
        return nil
      end
    end

    def self.unofficial(name)
      if File.exist?( name )
        return name
      elsif (File.exist?( path = File.join(@opts[:unofficial_parts_dir], 'parts', name)))
        return path
      elsif (File.exist?(path = File.join(@opts[:unofficial_parts_dir], 'p', name)))
        return path
      elsif (File.exist?(path = File.join(@opts[:unofficial_parts_dir], 'parts/s', name)))
        return path
      else
        return nil
      end
    end

    def self.ary_to_trans(a)
      x,y,z,a,b,c,d,e,f,g,h,i = a
      r1 = [a, d, g, 0.0]
      r2 = [b, e, h, 0.0]
      r3 = [c, f, i, 0.0]
      r4 = [x, y, z, 1.0]
      na = r1 + r2 + r3 + r4
      na.map!{|e| e.to_f}
      Geom::Transformation.new(na)
    end

    def self.swap_needed(ary)
      p1, p2, p3, p4 = ary
      n1 = ((p1.vector_to p4) * (p1.vector_to p2)).normalize
      n2 = ((p2.vector_to p1) * (p2.vector_to p3)).normalize
      n3 = ((p3.vector_to p2) * (p3.vector_to p4)).normalize
      n4 = ((p4.vector_to p3) * (p4.vector_to p1)).normalize
      return true if (dot = n1.dot n2) <= 0.0
      return true if (dot = n1.dot n3) <= 0.0
      return true if (dot = n1.dot n4) <= 0.0
      return true if (dot = n2.dot n3) <= 0.0
      return true if (dot = n2.dot n4) <= 0.0
      return true if (dot = n3.dot n4) <= 0.0
      return false
    end

    def self.swap_points(ary, i, j)
      ary[j], ary[i] = ary[i], ary[j]
    end

    def self.make_steps
      model = Sketchup.active_model
      layers = model.layers
      pages = model.pages
      layers.purge_unused
      layers = layers.to_a
      layers.shift #layer0
      pages.add
      layers.each { |layer| layer.visible =  false }
      layers.each do |layer|
        layer.visible = true
        pages.add(layer.name, 32)
      end
    end

  end # LDraw
end # JF
