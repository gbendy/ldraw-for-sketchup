# Loader for LDraw for SketchUp
#
module JF
  module LDraw
    LDRAW_DIR = 'C:\Program Files (x86)\LDraw'
    SKETCHUP_PARTS = ENV['HOMEPATH'] + '/LDraw/SketchUp'
    COLOR = {}

    load "#{File.dirname(__FILE__)}/importer.rb"
    load "#{File.dirname(__FILE__)}/exporter.rb"
    load "#{File.dirname(__FILE__)}/color.rb"

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

    menu.add_item("Import Materials") {
      JF::LDraw.import_materials
    }

    menu.add_item('About') {
      UI.openURL('https://github.com/jimfoltz/LDraw-for-SketchUp')
    }

    menu.add_item('Open Part') {
      file = UI.openpanel('Edit Part', SKETCHUP_PARTS, '*.skp')
      return unless file
      Sketchup.open_file(file)
    }

  end
end
