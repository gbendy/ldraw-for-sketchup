$str = "<"
puts "=" * 10
def listener(s)
   $str += s
end
begin
   SKSocket.connect "www.ldraw.org", 80
   SKSocket.add_socket_listener {|e| listener e}
   SKSocket.write "GET /library/official/parts/3005.dat http/1.0\n\n"
   # sksocket.sleep
rescue
   p $!
ensure
   #SKSocket.disconnect
end

p $str

UI.openURL("http://www.ldraw.org/library/official/parts/3005.dat")

