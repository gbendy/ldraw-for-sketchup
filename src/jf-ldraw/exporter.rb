module JF
  module LDraw

    def self.ui_export
      model_name = Sketchup.active_model.title + '.ldr'
      @file = UI.savepanel('Export', "", model_name)
      #name = get_export_filename
      File.open(@file, 'w') do |f|
        export(f)
      end
    end

    def self.export(file_object)
      model = Sketchup.active_model
      model.entities.each do |ins|
        a = ins.transformation.to_a
        file_object.write('1 16 ')
        file_object.write("#{a[12]} #{a[13]} #{a[14]} ")
        file_object.write("#{a[0]} #{a[4]} #{a[8]} ")
        file_object.write("#{a[1]} #{a[5]} #{a[9]} ")
        file_object.write("#{a[2]} #{a[6]} #{a[10]} ")
        file_object.write("#{ins.definition.name}.dat\n")
      end
      file_object.write("0\n")
    end

  end
end
