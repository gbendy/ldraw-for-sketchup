module JF
  module LDraw

    COLOR_PLUGINS = []
    
    # Base class for users to implement their own color plugin.
    # Implementations registered with JF::LDraw.add_color_plugin
    # will be called after each color has been added to the model and
    # allows for custom material setup. This can be used to setup high
    # quality materials for 3rd party renderers.
    class ColorPlugin
        # Called when a color is imported into the scene. Allows a user to modify
        # the SketchUp material created.
        # \param material the SketchUp material that represents the color. This already has the value and any alpha applied.
        # \param color a Color class representing the color being imported from the LDConfig file.
        # \param opts the LDraw configuration options.
        def import(material,color,opts)
        end
    end
    
    # Adds a color plugin. Whenever a material is imported the plugin will be called.
    # \p plugin the plugin to add.
    def self.add_color_plugin(plugin)
      if (!plugin.nil?)
        COLOR_PLUGINS.push(plugin)
      end
    end

    # Removes a color plugin.
    # \p plugin the plugin to remove.
    def self.remove_color_plugin(plugin)
      if (!plugin.nil?)
        COLOR_PLUGINS.delete(plugin)
      end
    end
    
  end
end
