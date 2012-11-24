# dat_importer.rb Copyright (c) 2009 jim.foltz@gmail.com
#
require 'sketchup'


module JF
  module LDraw

    CMD_COMMENT = 0
    CMD_FILE    = 1
    CMD_TRI     = 3
    CMD_QUAD    = 4

    def self.import_part_by_number()
      init()
      @last_pn = "3001" unless @last_pn
      ret = UI.inputbox(["Part No"], [@last_pn], "Import DAT")
      unless ret
        Sketchup.status_text = "Canceled."
        return
      end
      @last_pn = ret[0]
      @part_no = ret[0]+".dat"
      go ret[0]+".dat"
      return ret[0]
    end

    def self.init
      # @ldrawdir = 'C:/LDraw'
      @ldrawdir = 'C:/Program Files (x86)/LDraw'
    end

    def self.get_file
      init()
      file = UI.openpanel("Model", @ldrawdir, "*.dat")
      return unless file
      go(File.basename(file))
    end

    def self.go(pn)
      init()
      file = rel_path_to(pn)
      if file.nil?
        UI.messagebox("No part: #{pn}")
        return
      end
      name = File.basename(file, '')
      Sketchup.active_model.definitions.purge_unused
      f = File.new(File.join(@ldrawdir, file))
      first_line = f.readline
      first_line = first_line.gsub(/^0/, '').strip
      f.close
      cdef  = Sketchup.active_model.definitions.add(File.basename(name, '.dat'))
      cdef.description = first_line
      entities = cdef.entities
      Sketchup.active_model.start_operation "Import", true
      tr = Geom::Transformation.new
      read_file(file, entities, tr)
      ins = Sketchup.active_model.entities.add_instance(cdef, tr)
      Sketchup.active_model.commit_operation
    end



    def self.add_def(name, desc = "")
      name = name.split('.')[0]
      raise "#{__LINE__} - bad name." if name.empty? or name.nil?
      if((cdef = Sketchup.active_model.definitions[name]))
        return cdef
      else
        cdef = Sketchup.active_model.definitions.add(name) 
        pt = cdef.entities.add_cpoint([0, 0, 0])
        pt.layer = @const_layer
        return cdef
      end
    end

    def self.read_file(file, container, matrix)
      #p file
      file = File.join(@ldrawdir, file)
      lines = IO.readlines(file)
      lines.each_with_index do |line, i|
        ary = line.split
        #next if ary[0] == "0" or ary.empty?
        cmd = ary.shift
        cmd = cmd.to_i
        color = ary.shift
        case cmd
        when CMD_FILE # File
          name = (ary.pop).downcase
          raise "Bad array line #{i} #{File.basename(file)}" if ary.length != 12
          part_m = ary_to_trans(ary)
          next if name[/edge/i]
          part_def = add_def(name)
          if part_def.entities.length <= 1
            read_file(rel_path_to(name), part_def.entities, matrix)
          end
          part = container.add_instance(part_def, part_m)
        when CMD_TRI
          ary.map!{|e| e.to_f }
          pts = [ ary[0, 3], ary[3, 3], ary[6, 3] ]
          pts.map!{|e| Geom::Point3d.new(e)}
          pts.map!{|e| e.transform!(matrix)}
          begin
            face = container.add_face(pts)
          rescue => e
            puts "CMD_TRI: add_face error:#{e}\n#{pts.inspect}"
          end
        when CMD_QUAD
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
            puts "CMD_QUAD: add_face error:#{e}\n#{pts.inspect}"
            container.add_face(pts[0], pts[1], pts[3])
            container.add_face(pts[1], pts[2], pts[3])
          end
        end
      end
    end

    def self.rel_path_to(name)
      name += ".dat" unless(name.split('.')[1] == "dat")
      if (File.exist?( path = File.join(@ldrawdir, "parts", name)))
        return "parts/#{name}"
      elsif (File.exist?(path = File.join(@ldrawdir, "p", name)))
        return "p/#{name}"
      elsif (File.exist?(path = File.join(@ldrawdir, "parts/s", name)))
        return "parts/s/#{name}"
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
      t = Geom::Transformation.new(na)
    end

    def self.swap_needed(ary)
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

    def self.swap_points(ary, i, j)
      ary[j], ary[i] = ary[i], ary[j]
    end

  end # LDraw
end # JF
