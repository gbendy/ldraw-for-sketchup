module JF
  module LDraw
    def self.round_at(n, d ) #d=0
      (n * (10.0 ** d)).round.to_f / (10.0 ** d)
    end

    def self.ui_export
      model = Sketchup.active_model
      instances = model.entities.grep(Sketchup::ComponentInstance)
      if instances.length < 1
        UI.messagebox('No ComponentInstances to Export.')
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
        a.map!{|e| round_at(e, 4)}
        file_object.write('1 ')
        mat_name = ins.material ? ins.material.name : '16'
        file_object.write(mat_name)
        file_object.write(" #{a[12]} #{a[13]} #{a[14]} ")
        file_object.write("#{a[0]} #{a[4]} #{a[8]} ")
        file_object.write("#{a[1]} #{a[5]} #{a[9]} ")
        file_object.write("#{a[2]} #{a[6]} #{a[10]} ")
        file_object.write("#{ins.definition.name}.dat\n")
      end
      file_object.write("0\n")
    end

    def self.export_layer_images
      model = Sketchup.active_model
      layers = model.layers
      name = "000"
      layers.each do |layer|
        layers_off
        layer.visible = true
        model.active_view.zoom_extents
        out = File.join(TEMP_PATH, "l#{name}.png")
        model.active_view.write_image(out)
        name.next!
      end
    end

    def self.export_scene_images
      model = Sketchup.active_model
      name = '000'
      pages = model.pages
      pages.each do |page|
        pages.selected_page = page
        out = File.join(TEMP_PATH, "p#{name}.png")
        model.active_view.write_image(out)
        name.next!
      end
    end

    def self.a
      export_layer_images
      export_scene_images
      # GraphicsMagick commands
      #`gm mogrify -verbose -resize 225 -border 2x2 l*.png`
      #`gm mogrify -verbose -border 1x1 p*.png`
      ##`gm mogrify -verbose -draw "text 0,0 Step" p*.png`

      #Dir["l*.png"].each do |limg|
      #  base_img = limg.delete('l')
      #  cmd = "gm composite -verbose l#{base_img} p#{base_img} #{base_img}"
      #  `#{cmd}`
      #end
      # gm montage -tile 2x -geometry +0+0 %.png  tmpimg.png
    end


    def self.layers_off
      Sketchup.active_model.layers.map{|l| l.visible = false}
    end

  end
end
