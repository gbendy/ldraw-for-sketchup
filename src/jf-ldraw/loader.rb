# Loader for LDraw for SketchUp
#

load "#{File.dirname(__FILE__)}/dat_importer.rb"

menu = UI.menu('File')

cmd  = UI::Command.new("Import LDraw by PN") {
  JF::LDraw.import_part_by_number
}

menu.add_item(cmd)
