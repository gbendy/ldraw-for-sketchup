# Loader for LDraw for SketchUp
#
module JF
  module LDraw

    load "#{File.dirname(__FILE__)}/config.rb"
    load "#{File.dirname(__FILE__)}/importer.rb"
    load "#{File.dirname(__FILE__)}/exporter.rb"
    load "#{File.dirname(__FILE__)}/color.rb"

    menu = UI.menu('Plugins').add_submenu('LDraw')

    #menu.add_item('Import Definitions') { JF::LDraw.import_definitions }
    menu.add_item('Import Part No') { JF::LDraw.ui_import_part_by_number }
    menu.add_item('Import Model (.ldr)') { JF::LDraw.ui_get_file }
    menu.add_separator
    menu.add_item("Export .ldr") { JF::LDraw.ui_export }
    menu.add_separator
    menu.add_item("Import Materials") { JF::LDraw.import_materials }
    menu.add_separator
    menu.add_item('About') {
      UI.openURL('https://github.com/jimfoltz/LDraw-for-SketchUp')
    }

    menu.add_item('Open Part') {
      file = UI.openpanel('Edit Part', SKETCHUP_PARTS, '*.skp')
      return unless file
      Sketchup.open_file(file)
    }

    UI.add_context_menu_handler do |menu|
      menu.add_item("Save to LDraw Lib") do 
        ins = Sketchup.active_model.selection[0]
        cdef = ins.definition
        cdef.save_as(SKETCHUP_PARTS + '/' + cdef.name + '.skp')
      end
    end

  end # LDraw
end # JF
