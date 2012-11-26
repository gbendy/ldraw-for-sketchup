# Because SketchupExtension can't load a .rbs directly

require 'sketchup'

Sketchup.require File.dirname(__FILE__)+"/ldraw_r1.0.rb"
#Sketchup.require File.dirname(__FILE__)+"/ldraw_dev.rb"
Sketchup.require File.dirname(__FILE__)+"/LDrawPositioner.rb"
