module JF
  module LDraw
    #LD_CONFIG = File.join(LDRAW_DIR, 'LDConfig.ldr')
    #LD_CONFIG = File.join('C:/LDraw', 'LDConfig.ldr')

    COLOR_PROCESSORS = []
    
    # Represents an LDraw color. Contains the following attributes:
    #    code - the color code
    #    name - the color name
    #    rgb - Sketchup::Color containing the RGBA color of this color
    #    alpha - float (0-255), the alpha value of the color
    #    luminance - float, the luminance value of the color
    #    finish - string, the surface finish of the color:
    #        SOLID - a standard solid color
    #        CHROME - chrome finish
    #        METAL - metallic finish
    #        MATTE_METALLIC - brushed metallic finish
    #        PEARLESCENT - pearlescent finish
    #        RUBBER - rubber finish
    #        MATERIAL - a material finish. The material attribute contains the material parameters.
    #    material - hash, contains the specific material parameters. name is the only compulsory element,
    #                 all others are material dependent. Those listed below are used by the official 
    #                 GLITTER and SPECKLE materials. Parameter VALUE will automatically be converted to
    #                 an RGBA SketchUp Color, all others will be strings.
    #        name - string, the name of the material, usually GLITTER or SPECKLE
    #        VALUE - Sketchup::Color the finish color
    #        ALPHA - string (0-255), the alpha value of the finish
    #        LUMINANCE - string, the luminance value of the finsh
    #        FRACTION - string fraction
    #        VFRACTION - string vfraction
    #        SIZE - string size
    #        MINSIZE - string min size
    #        MAXSIZE - string max size
    #
    #  See http://www.ldraw.org/article/299 for a description of the LDraw color specifications
    class Color
      attr_accessor :code
      attr_accessor :name
      attr_accessor :rgb
      attr_accessor :alpha
      attr_accessor :luminance
      attr_accessor :finish
      attr_accessor :material
      
      def initialize(init=nil?)
        @code=nil
        @name=""
        @rgb=Sketchup::Color.new()
        @alpha=255.to_f
        @luminance=0.to_f
        @finish="SOLID"
        @material={}
        return if init.nil?
        if (init.class == String)
          line = init.strip
          code  = /CODE\s+(\d+)/.match(line)
          value = /VALUE\s+\#([a-fA-F0-9]+)/.match(line)
          alpha = /ALPHA\s+(\d+)/.match(line)
          if code
            code = code[1]
            #puts "code:#{code[1].inspect}"
            if value
              @code = code
              @rgb = value_to_color(value[1],!alpha ? 255 : alpha[1])
              name = /!COLOUR\s+([[:graph:]]+)/.match(line)
              if (name)
                @name = name[1]
              end
              ["CHROME","METAL","MATTE_METALLIC","PEARLESCENT","RUBBER","MATERIAL"].each { |key|
                match = /#{key}/.match(line)
                if (match)
                  @finish=key
                  if (key == "MATERIAL")
                    params = match.post_match.strip.split()
                    @material["name"] = params.shift.strip
                    while (params.length != 0)
                      @material[params.shift.strip] = params.shift.strip
                    end
                    if (!@material["VALUE"].nil?)
                      # convert value to a colour
                      @material["VALUE"] = value_to_color(@material["VALUE"].delete("#"),@material["ALPHA"])
                    end
                  end
                  # only 1 finish
                  break
                end
              }
              if (alpha) 
                @alpha = alpha[1].to_f
              end
              luminance = /LUMINANCE\s+(\d+)/.match(line)
              if (luminance)
                @luminance = luminance[1].to_f
              end
            end
          end
        end
      end

      def value_to_color(value,alpha=255)
        rgb = value.scan(/../).map{|e| e.to_i(16)}
        rgb << (alpha.nil? ? 255 : alpha.to_i)
        return Sketchup::Color.new(rgb)
      end      
    end
    
    # Base class for users to implement their own color processor.
    # Implementations registered with JF::LDraw.add_color_processor
    # will be called after each color has been added to the model and
    # allows for custom material setup. This can be used to setup high
    # quality materials for 3rd party renderers.
    class ColorProcessor
        # Called when a color is imported into the scene. Allows a user to modify
        # the SketchUp material created.
        # \param material the SketchUp material that represents the color. This already has the value and any alpha applied
        # \param color a Color class representing the color being imported from the LDConfig file
        # \param opts the LDraw configuration options
        def process(material,color,opts)
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
        color = Color.new(line)
        COLOR[color.code] = color if !color.code.nil?
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
        mat.color = COLOR[code].rgb
        mat.alpha = COLOR[code].alpha / 255.0
        COLOR_PROCESSORS.each { |p| p.process(mat,COLOR[code],@opts) }
        
        return mat
      end
    end

  end
end
