dlg=UI::WebDialog.new

dlg.set_file (File.join(File.dirname(__FILE__), "frame.html"))

dlg.add_action_callback("go"){ |d, a|
   get_image(d, a)
}
dlg.add_action_callback("next") { |d, a|
   n = a.to_i.succ
   get_image(d, n)
}
def get_image(d, n)
   d.execute_script("$('pn').value=#{n}")
  d.execute_script("document.getElementById('fr').src='http://img.lugnet.com/ld/#{n}.gif'")
end
dlg.show


