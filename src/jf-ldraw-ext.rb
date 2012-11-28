require 'sketchup'
require 'extensions'

module JF
  module LDraw
    extension = SketchupExtension.new(
      'LDraw Tools',
      'jf-ldraw/loader.rb'
    )
    extension.description = 'LDraw Tools for SketchUp'
    extension.version     = '0.1'
    extension.copyright   = '2012 jim.foltz@gmail.com'
    extension.creator      = 'Jim Foltz'

    Sketchup.register_extension(extension, true)
  end
end
