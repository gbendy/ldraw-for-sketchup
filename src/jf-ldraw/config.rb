module JF
  module LDraw

    # For add_faces_from_mesh
    module Smooth
      NONE             = 0
      SOFTEN           = 4
      SMOOTH           = 8
      SOFTEN_AND_SOOTH = SOFTEN + SMOOTH
    end

    @opts = {}
    @opts[:ldraw_dir] = 'C:/Program Files (x86)/LDraw'
    @opts[:autosave_imported_parts] = false
    @opts[:smoothing] = Smooth::NONE
    @opts[:use_unofficial_parts] = true
    @opts[:unofficial_parts_dir] = 'C:/Users/Jim/Downloads/ldrawunf'

    #LDRAW_DIR = 'C:/LDraw'
    SKETCHUP_PARTS = ENV['HOMEPATH'] + '/LDraw/SketchUp'
    COLOR = {}
    LD_CONFIG = File.join('C:/LDraw', 'LDConfig.ldr')


    # LDraw Lne  Types
    CMD_COMMENT = 0
    CMD_FILE    = 1
    CMD_LINE    = 2
    CMD_TRI     = 3
    CMD_QUAD    = 4

    SMOOTH      = 0
    TR = Geom::Transformation.rotation(ORIGIN, X_AXIS, 90.degrees)

  end # LDraw
end # JF
