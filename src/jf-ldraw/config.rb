module JF
  module LDraw

    @opts = {}
    @opts[:ldraw_dir]               = 'C:/Program Files (x86)/LDraw'
    @opts[:unofficial_parts_dir]    = ENV['HOMEPATH'] + '/Downloads/ldrawunf'
    @opts[:model_import_dir]        = ENV['HOMEPATH'] + '/Downloads'
    @opts[:model_export_dir]        = ENV['HOMEPATH'] + '/Downloads'
    @opts[:su_models_dir]           = ENV['HOMEPATH'] + '/LDraw/SketchUp'
    @opts[:use_unofficial_parts]    = true
    #@opts[:autosave_imported_parts] = false
    # If true then incoming parts have their transform checked for validity. If 
    # invalid they are discarded.
    @opts[:validate_transform]      = true
    # If true then the imported LDR is made into a component rather than
    # imported into the root of the scene.
    @opts[:make_component]          = false
    # If true then scales the imported model to real world scale.
    # Only effective if MAKE_COMPONENT is also true.
    # Note this only affects the generated component, individual part
    # definitions are still in LDR scale.
    @opts[:physical_scale]          = true
    
    SKETCHUP_PARTS = ENV['HOMEPATH'] + '/LDraw/SketchUp'
    COLOR = {}
    LD_CONFIG = File.join('C:/LDraw', 'LDConfig.ldr')
    TEMP_PATH = File.expand_path( ENV['TMPDIR'] || ENV['TMP'] || ENV['TEMP'] ).freeze

    # LDraw Lne  Types
    CMD_COMMENT = 0
    CMD_FILE    = 1
    CMD_LINE    = 2
    CMD_TRI     = 3
    CMD_QUAD    = 4

    TR = Geom::Transformation.rotation(ORIGIN, X_AXIS, 90.degrees)

    # Snoothing for for add_faces_from_mesh
    NO_SMOOTHING     = 0
    SOFTEN_ONLY      = 4
    SMOOTH_ONLY      = 8
    SOFTEN_AND_SOOTH = 12
  end # LDraw
end # JF
