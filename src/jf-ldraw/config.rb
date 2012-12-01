module JF
  module LDraw

    LDRAW_DIR = 'C:/LDraw'
    SKETCHUP_PARTS = ENV['HOMEPATH'] + '/LDraw/SketchUp'
    COLOR = {}
    LD_CONFIG = File.join('C:/LDraw', 'LDConfig.ldr')
    CMD_COMMENT = 0
    CMD_FILE    = 1
    CMD_LINE    = 2
    CMD_TRI     = 3
    CMD_QUAD    = 4

    SMOOTH      = 0
    OPTS = {}
    OPTS[:ldraw_dir] = 'C:/Program Files (x86)/LDraw'
  end
end