load "#{File.dirname(__FILE__)}/dat_importer.rb"

menu = UI.menu('File')#.add_submenu('LDraw Import')
cmd  = UI::Command.new("LDraw Import by PN") {
  JF::LDraw.import_part_by_number
}
menu.add_item(cmd)
#cmd = UI::Command.new("Import File") { JF::LDraw.get_file }
#menu.add_item(cmd)

