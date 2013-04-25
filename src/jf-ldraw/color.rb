module JF
  module LDraw
    #LD_CONFIG = File.join(LDRAW_DIR, 'LDConfig.ldr')
    #LD_CONFIG = File.join('C:/LDraw', 'LDConfig.ldr')

    COLOR_PROCESSORS = []
    
    # Base class for users to implement their own color processor.
    # Implementations registered with JF::LDraw.add_color_processor
    # will be called after each color has been added to the model and
    # allows for custom material setup. This can be used to setup high
    # quality materials for 3rd party renderers.
    class ColorProcessor
        # Called when a color is imported into the scene. Allows a user to modify
        # the SketchUp material created.
        # \p material the SketchUp material that represents the color. This already has the value and any alpha applied from the LDconfig file.
        # \p color Hash containing information about the color being imported from the LDConfig file:
        #    code - the color code
        #    rgb - Sketchup::Color containing the RGBA color of this color
        #    name - the color name
        #    metadata - Hash containing additional metadata about the color. Has one or more of the following:
        #        SOLID - true, is a standard solid color
        #        ALPHA - float (0-255), the alpha value of the color
        #        LUMINANCE - float, the luminance value of the color
        #        CHROME - true, has a chrome finish
        #        METAL - true, has a metallic finish
        #        PEARLESCENT - true, has a pearlescent finish
        #        RUBBER - true, has a rubber finish
        #        MATERIAL GLITTER - hash, has a glitter finish, value contains the specific glitter values
        #            value - Sketchup::Color glitter color
        #            fraction - float fraction
        #            vfraction - float vfraction
        #            size - float size
        #        MATERIAL SPARKLE - hash, has a speckle finish, value contains the specific speckle values
        #            value - Sketchup::Color speckle color
        #            fraction - float fraction
        #            minsize - float min size
        #            maxsize - float max size
        def process(material,color)
        end
    end
    
    # Adds a color processor. Whenever a material is imported the processor will be called
    # \p processor the processor to add.
    def self.add_color_processor(processor)
      if (!processor.nil?)
        COLOR_PROCESSORS.push(processor)
      end
    end

    # Removes a color processor
    # \p processor the processor to remove.
    def self.remove_color_processor(processor)
      if (!processor.nil?)
        COLOR_PROCESSORS.delete(processor)
      end
    end
    
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
              color = {}
              rgb = value[1].scan(/../).map{|e| e.to_i(16)}
              if alpha
                rgb << alpha[1].to_f / 255.0
              else
                rgb << 255
              end
              color["code"] = code
              color["rgb"] = Sketchup::Color.new(rgb)
              name = /!COLOUR\s+([[:graph:]]+)/.match(line)
              if (name)
                color["name"] = name[1]
              end
              metadata = {}
              ["CHROME","METAL","PEARLESCENT","RUBBER","MATERIAL GLITTER","MATERIAL SPECKLE"].each { |key|
                match = /#{key}/.match(line)
                if (match)
                  data = true
                  if (key == "MATERIAL GLITTER")
                    post = match.post_match.strip
                    data = {}
                    value = /VALUE\s+\#([a-fA-F0-9]+)/.match(post)
                    fraction = /FRACTION\s+([0-9.]+)/.match(post)
                    vfraction = /VFRACTION\s+([0-9.]+)/.match(post)
                    size = /SIZE\s+([0-9.]+)/.match(post)
                    rgb = value[1].scan(/../).map{|e| e.to_i(16)}
                    rgb << 255
                    data["value"] = Sketchup::Color.new(rgb)
                    data["fraction"] = fraction[1].to_f
                    data["vfraction"] = vfraction[1].to_f
                    data["size"] = size[1].to_f
                  elsif (key == "MATERIAL SPECKLE")
                    post = match.post_match.strip
                    data = {}
                    value = /VALUE\s+\#([a-fA-F0-9]+)/.match(post)
                    fraction = /FRACTION\s+([0-9.]+)/.match(post)
                    minsize = /MINSIZE\s+([0-9.]+)/.match(post)
                    maxsize = /MAXSIZE\s+([0-9.]+)/.match(post)
                    rgb = value[1].scan(/../).map{|e| e.to_i(16)}
                    rgb << 255
                    data["value"] = Sketchup::Color.new(rgb)
                    data["fraction"] = fraction[1].to_f
                    data["minsize"] = minsize[1].to_f
                    data["maxsize"] = maxsize[1].to_f
                  end
                  metadata[key] = data
                end
              }
              # if none of the above then we're a basic solid brick
              if (metadata.size == 0)
                metadata["SOLID"] = true
              end
              if (alpha) 
                metadata["ALPHA"] = alpha[1].to_f
              end
              luminance = /LUMINANCE\s+(\d+)/.match(line)
              if (luminance)
                metadata["LUMINANCE"] = luminance[1].to_f
              end
              
              color["metadata"] = metadata
              COLOR[code] = color
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
        mat.color = COLOR[code]["rgb"]
        mat.alpha = COLOR[code]["rgb"].alpha / 255.0
        COLOR_PROCESSORS.each { |p| p.process(mat,COLOR[code]) }
        
        return mat
      end
    end

  end
end
