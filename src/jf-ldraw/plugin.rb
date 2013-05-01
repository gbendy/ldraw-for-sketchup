module JF 
  module LDraw 
 
    COLOR_PLUGINS = [] # :nodoc:
    PART_PLUGINS = [] # :nodoc:
    
    # Base class for users to implement their own color plugin.
    # Implementations registered with JF::LDraw.add_color_plugin
    # will be called after each color has been added to the model and
    # allows for custom material setup. This can be used to setup high
    # quality materials for 3rd party renderers.
    class ColorPlugin
        # Called when a color is imported into the scene. Allows a user to modify
        # the SketchUp material created.
        # +material+:: the SketchUp material that represents the color. This already has the value and any alpha applied.
        # +color+:: a Color class representing the color being imported from the LDConfig file.
        # +opts+:: the LDraw configuration options.
        def import(material,color,opts)
        end
    end
  
    # Base class for users to implement their own part plugin.
    # Implementations registered with JF::LDraw.add_part_plugin
    # will be called when a part is imported to allow custom part definitions to
    # be created.
    class PartPlugin
        # Called whenever a part needs to be imported into the scene. If the plugin can import the part it must add a 
        # definition called \p name to Sketchup.active_model.definitions, populate it with geometry and
        # return the definition. If the importer cannot import the part it must return \c nil.
        # Plugins have highest priority for part import, followed by models in the @opts[:su_models_dir]
        # directory, followed by reading the LDraw dat file.
        # +name+:: the name of the part to import.
        # +opts+:: the LDraw configuration options.
        # +return+:: the imported definition or \c nil if unable to import.
        def import(name,opts)
          nil
        end
        
        # Called after import to allow for modification of the part definition.
        # +name+:: the name of the imported part.
        # +definition+:: the imported component definition
        # +metadata+:: hash containing information about the part where available. Elements include:
        #              _source_:: where the definition came from, either string +skp+ if a SketchUp override file, 
        #                         +dat+ if from an LDraw dat file or the plugin class instance used if from a part plugin.
        #              _type_:: the part type, one of the strings +part+, +subpart+, +primitive+ or +nil+ if unknown
        # +opts+:: the LDraw configuration options.
        def post_import(name,definition,metadata,opts)
        end
    end
      
    # Adds a color plugin. Whenever a material is imported the plugin will be called.
    # +plugin+:: the ColorPlugin to add.
    def self.add_color_plugin(plugin)
      if (!plugin.nil?)
        COLOR_PLUGINS.push(plugin)
      end
    end

    # Removes a color plugin.
    # +plugin+:: the ColorPlugin to remove.
    def self.remove_color_plugin(plugin)
      if (!plugin.nil?)
        COLOR_PLUGINS.delete(plugin)
      end
    end

    # Adds a part plugin. Whenever a part is imported the plugin will be called.
    # +plugin+:: the PartPlugin to add.
    def self.add_part_plugin(plugin)
      if (!plugin.nil?)
        PART_PLUGINS.push(plugin)
      end
    end

    # Removes a part plugin.
    # +plugin+:: the PartPlugin to remove.
    def self.remove_part_plugin(plugin)
      if (!plugin.nil?)
        PART_PLUGINS.delete(plugin)
      end
    end
        
  end
end
