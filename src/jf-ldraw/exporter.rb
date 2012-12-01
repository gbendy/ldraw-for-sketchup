module JF
  module LDraw

    def self.ui_export
      model = Sketchup.active_model
      instances = model.grep(Sketchup::Componentinstnce)
      if instancces.length < 1
        UI.messagebx('No ComponentInsances to Export.')
        return
      end
      model_title = model.title
      model_title = 'Untitled' if model_title.empty?
      model_name = model_title + '.ldr'
      file = UI.savepanel('Export', "", model_name)
      if file
        if File.extname(file).empty?
          file << '.ldr'
        end
        File.open(file, 'w') { |f| export_instances(f) }
      end
    end

    # Export top-level ComponentInstances
    def self.export_instances(file_object)
      model = Sketchup.active_model
      model.active_entities.grep(Sketchup::ComponentInstance).each do |ins|
        a = (TR * ins.transformation).to_a
        file_object.write('1 ')
        file_object.write(ins.material.name)
        file_object.write(" #{a[12]} #{a[13]} #{a[14]} ")
        file_object.write("#{a[0]} #{a[4]} #{a[8]} ")
        file_object.write("#{a[1]} #{a[5]} #{a[9]} ")
        file_object.write("#{a[2]} #{a[6]} #{a[10]} ")
        file_object.write("#{ins.definition.name}.dat\n")
      end
      file_object.write("0\n")
    end

  end
end
