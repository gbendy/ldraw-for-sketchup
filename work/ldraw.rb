=begin

Possible Ldraw objects

  Model - a collection (tree) of Parts
  Color/Material
  Part - A Collection of Geometry and/or Primitives
  Primitive/SubPart
  File - .mpd, .ldr, .dat
  Line or LineType
  Location of Part Library

=end
require 'set'

module LDraw
  LDRAW_DIR = 'C:/Program Files (x86)/LDraw'.freeze
  LINETYPE_COMMENT  = 0
  LINETYPE_FILE     = 1
  LINETYPE_LINE     = 2
  LINETYPE_TRI      = 3
  LINETYPE_QUAD     = 4
  LINETYPE_OPTIONAL = 5
  class LDFile
    attr_accessor :filename
    attr_reader :lines, :files
    def initialize(opts = {})
      @filename = opts.fetch(:filename, nil)
      @lines = []
      @tree = nil
      @files = Set.new
    end
    def add_line(line)
      line.strip!
      @lines << line
    end
    def read_lines
      IO.foreach(filename) do |line|
        add_line(line)
      end
    end
    def parse
      in_file = false
      curr_file = nil
      @lines.each do |line|
        ary = line.split(/\s/)
        cmd = ary.shift
        if cmd == '0'
          if ary.length == 0 or ary[0] == "NOFILE"
            in_file = false
          end
          if ary[0] == "FILE"
            in_file = true
            ary.shift
            name = ary.join(' ')
            ext = File.extname(name)
            curr_file = LDFile.new({:filename => name})
            @files.add @curr_file
          end
        end
        if in_file
          curr_file.add_line line
        end
      end

    end
      
  end # MPDFile
  
end # LDraw

if $0 == __FILE__
  require 'awesome_print'
  require 'pp'
  mpd = LDraw::LDFile.new
  mpd.filename = ARGV.shift.strip
  mpd.read_lines
  mpd.parse
  pp mpd
end
__END__

  mpd = []
  state = false
  last = nil

  file = ARGV.shift.chomp
  IO.foreach(file) do |line|
    line.strip!
    ary = line.split(/\s/)
    cmd = ary.shift
    if cmd == "0"
      if ary.length == 1 or ary[1] == "NOFILE"
        state = false
        next
      end
      if ary[0] == "FILE"
        ary.shift
        name = ary.join(' ')
        f = {}
        f[name] = []
        mpd << f
        last = f[name]
        state = true
      end
    end
    last << line
  end

  require 'awesome_print'
  ap mpd
