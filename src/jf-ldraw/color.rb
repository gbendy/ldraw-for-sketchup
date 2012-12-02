module JF
  module LDraw
    #LD_CONFIG = File.join(LDRAW_DIR, 'LDConfig.ldr')
    #LD_CONFIG = File.join('C:/LDraw', 'LDConfig.ldr')

    def self.import_materials
      parse_colors
      Sketchup.active_model.start_operation('Import Materials', true)
      COLOR.keys.each do |code|
        get_or_add_material(code)
      end
      Sketchup.active_model.commit_operation
    end


    def self.parse_colors
      IO.foreach(LD_CONFIG) do |line|
        line.strip!
        code  = /CODE\s+(\d+)/.match(line)
        value = /VALUE\s+\#([a-fA-F0-9]+)/.match(line)
        alpha = /ALPHA\s+(\d+)/.match(line)
          if code
            code = code[1]
            #puts "code:#{code[1].inspect}"
            if value
              rgb = value[1].scan(/../).map{|e| e.to_i(16)}
              if alpha
                rgb << alpha[1].to_f / 255.0
              else
                rgb << 255
              end
              color = COLOR[code] = Sketchup::Color.new(rgb)
            end
          end
      end
      COLOR['16'] = nil
    end

    def self.get_or_add_material(code)
      return nil if code == '16'
      if ( mat = Sketchup.active_model.materials[code] )
        return mat
      elsif COLOR[code].nil?
        return nil
      else
        mat = Sketchup.active_model.materials.add(code)
        mat.color = COLOR[code]
        mat.alpha = COLOR[code].alpha / 255.0
        return mat
      end
    end

  end
end
