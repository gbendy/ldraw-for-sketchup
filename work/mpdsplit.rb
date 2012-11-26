#file = "BusinessTurboPropPlane.mpd"
file = ARGV.shift.chomp

tdir = "./tmp/"
flag = false
f = $stdout

IO.foreach(file) { |line|
  ary = line.split
  if ary[1] == "FILE"
    f = File.open(tdir+ary[2], "w")
    flag = true
  end
  if ary[0] == "0" and ary.length == 1
    flag = false
  end
  f.print line
}

