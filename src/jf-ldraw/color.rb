module JF
  module LDraw
    #LD_CONFIG = File.join(LDRAW_DIR, 'LDConfig.ldr')
    #LD_CONFIG = File.join('C:/LDraw', 'LDConfig.ldr')

    # Represents an LDraw color as read from +LDConfig.ldr+.
    # See http://www.ldraw.org/article/299 for a description of the LDraw color specifications
    class Color
      # the color code
      attr_accessor :code
      # the color name
      attr_accessor :name
      # Sketchup::Color containing the RGBA color of this color
      attr_accessor :rgb
      # float (0-255), the alpha value of the color
      attr_accessor :alpha
      # float, the luminance value of the color
      attr_accessor :luminance
      # string, the surface finish of the color. One of:
      # *SOLID*:: a standard solid color
      # *CHROME*:: chrome finish
      # *METAL*:: metallic finish
      # *MATTE_METALLIC*:: brushed metallic finish
      # *PEARLESCENT*:: pearlescent finish
      # *RUBBER*:: rubber finish
      # *MATERIAL*:: a material finish. The #material attribute contains the material parameters.
      attr_accessor :finish
      # hash, contains the specific material parameters. name is the only compulsory element,
      # all others are material dependent. Those listed below are used by the official 
      # +GLITTER+ and +SPECKLE+ materials. Parameter +VALUE+ will automatically be converted to
      # an RGBA SketchUp::Color, all others will be strings.
      # *name*:: string, the name of the material, usually +GLITTER+ or +SPECKLE+
      # *VALUE*:: Sketchup::Color the finish color
      # *ALPHA*:: string (0-255), the alpha value of the finish
      # *LUMINANCE*:: string, the luminance value of the finsh
      # *FRACTION*:: string fraction
      # *VFRACTION*:: string vfraction
      # *SIZE*:: string size
      # *MINSIZE*:: string min size
      # *MAXSIZE*:: string max size      
      attr_accessor :material
      
      # Creates a Color. Defaults to solid black, non-illuminating, no name, code == +nil+
      # *init*:: If supplied this must be a line following the +LDConfig.ldr+ format. The Color will be populated from that.
      #          If the line is successfully parsed then the code attribute will be non-nil.
      def initialize(init=nil)
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
              @rgb = Color.value_to_color(value[1],!alpha ? 255 : alpha[1])
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
                      @material["VALUE"] = Color.value_to_color(@material["VALUE"].delete("#"),@material["ALPHA"])
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

      # Converts an LDConfig color value to a Sketchup::Color
      # +value+:: the color value without the leading #
      # +alpha+:: the alpha value, default 255
      # +return+:: the Sketchup::Color
      def self.value_to_color(value,alpha=255)
        rgb = value.scan(/../).map{|e| e.to_i(16)}
        rgb << (alpha.nil? ? 255 : alpha.to_i)
        return Sketchup::Color.new(rgb)
      end      
    end
    
    def self.import_materials # :nodoc:
      parse_colors
      Sketchup.active_model.start_operation('Import Materials', true)
      COLOR.keys.each do |code|
        get_or_add_material(code)
      end
      Sketchup.active_model.commit_operation
    end


    def self.parse_colors # :nodoc:
      IO.foreach(LD_CONFIG) do |line|
        color = Color.new(line)
        COLOR[color.code] = color if !color.code.nil?
      end
      COLOR['16'] = nil
    end
    
    def self.get_or_add_material(code) # :nodoc:
      return nil if code == '16'
      if ( mat = Sketchup.active_model.materials[code] )
        return mat
      elsif COLOR[code].nil?
        return nil
      else
        mat = Sketchup.active_model.materials.add(code)
        mat.color = COLOR[code].rgb
        mat.alpha = COLOR[code].alpha / 255.0
        COLOR_PLUGINS.each { |p| p.import(mat,COLOR[code],@opts) }
        
        return mat
      end
    end

  end
end
