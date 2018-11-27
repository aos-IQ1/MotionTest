#!/usr/bin/env ruby

require 'pp'

require 'serialport'

def lines2byte(lines)
  lines.strip
   .split("\n")
  .map{|line| line.split(/\s+/).map{|num| num.to_i(16)}.pack("C*") }
end


def send(line, sp)
  # send command
  sp.write(line)

  # wait response (sync)
  while true do
    break if not @buf.nil? and @buf.first == @buf.size
  end
  @buf = nil
end


def sendlines(lines, sp)
  code = lines2byte(lines)
  pp code
    
  code.each{|line| 
    p line
    send(line, sp)
  }
end


sp = SerialPort.new(ARGV[0], 115200, 8, 1, SerialPort::EVEN) # 9600bps, 8bit, stopbit 1, parity none

t = Thread.new{
  puts "start"
  loop do
    #print "0x%x " % (sp.getc.unpack("C"))

    len = sp.getc.unpack(?C).first
    @buf = (len-1).times.inject([]){|ar, n|
      ar << sp.getc.unpack(?C).first
    }.unshift(len)
    p @buf
  end
}

trap(:INT){ t.kill }

#09 00 02 00 00 00 00 00 0B
#11 00 02 02 00 00 4B 04 00 00 00 00 00 00 00 00 64
#07 0C 80 0B 00 00 9E
#09 00 02 00 00 00 03 00 0E

sendlines("""
09 00 02 00 00 00 00 00 0B
11 00 02 02 00 00 4B 04 00 00 00 00 00 00 00 00 64
07 0C 80 0B 00 00 9E
09 00 02 00 00 00 03 00 0E
""", sp)

puts "POI"
