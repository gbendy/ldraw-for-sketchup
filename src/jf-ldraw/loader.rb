# Loader for LDraw for SketchUp
#

load "#{File.dirname(__FILE__)}/importer.rb"
load "#{File.dirname(__FILE__)}/exporter.rb"

menu = UI.menu('Plugins').add_submenu('LDraw')

menu.add_item('Import .ldr') {
  JF::LDraw.ui_get_file
}

menu.add_item('Enter Part No') {
  JF::LDraw.import_part_by_number
}

menu.add_item("Export .ldr") {
  JF::LDraw.ui_export
}

menu.add_item('About') {
  UI.openURL('https://github.com/jimfoltz/LDraw-for-SketchUp')
}
