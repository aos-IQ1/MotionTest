#!/usr/bin/env ruby

require 'pp'

require 'serialport'

# ロボットへの送信コマンドのチェックサム計算
def add_checksum(line)
  line + [line.sum & 0xFF].pack("C")
end

# コマンド文字列達(["04 00 ....", "07 0C...."])をバイト列の配列に変換
def lines2byte(lines)
  lines.strip
   .split("\n")
  .map{|line| add_checksum(line.split(/\s+/).map{|num| num.to_i(16)}.pack("C*")) }
end

# コマンドバイト列("\x00\00....")を送信後、ロボットからの受信を待機
def send(line, sp)
  # send command
  sp.write(line)

  # wait response (sync)
  while true do
    break if not @buf.nil? and @buf.first == @buf.size
  end
  @buf = nil
end

# コマンド文字列達(["04 00 ....", "07 0C...."])を送信
def sendlines(lines, sp)
  code = lines2byte(lines)
  pp code
    
  code.each{|line| 
    p line
    send(line, sp)
  }
end

# 1文字UARTから読んで0xFFみたいな書式で出力
def getc_and_print(sp)
  #print "Enter"
  c = sp.getc.unpack(?C).first
  print "0x%X " % c
  c
end

# {num => spee, position}
# { 1=>[ 0xFF, 0xFFFF], 2=>[0x01, 0x0000], ...}
def gen_multi_servo(spd, cmds)
  target_servo = cmds.keys
    .inject(Array.new(5, 0)){|bytes, servo| 
      i = servo.div(8)
      bytes[i] += ( 1 << (servo-8*i-1) ) 
      bytes
    }
  spd_posi = [spd] + cmds.values.map{|position|
    [position&0xFF, (position>>8)&0xFF]
  }.flatten
  p target_servo
  main = [0x10] + target_servo + spd_posi
  ([main.size+2] + main).map{|n| "%02X" % n}.join(" ")
end

#puts gen_multi_servo(ARGV[1].to_i, 
#                     Hash[ ARGV[2..-1].each_slice(2).map{|n| n.map(&:to_i)} ] )
#exit

sp = SerialPort.new(ARGV[0], 115200, 8, 1, SerialPort::EVEN) # 9600bps, 8bit, stopbit 1, parity none

t = Thread.new{
  puts "start"
  loop do
    # コマンド長さの取得(最初のバイトはコマンド長)	
    len = getc_and_print(sp)
    # コマンドの受信
    @buf = (len-1).times.inject([]){|ar, n|
      ar << getc_and_print(sp)
    }.unshift(len)
    puts "\n#{ @buf.inspect }"
    # モーション終了判定
    #break if not @buf.nil? and @buf.pack("C*").include? "POI"
  end
}

trap(:INT){ 
  puts "kill"
  t.kill 
}

cmd = gen_multi_servo(ARGV[1].to_i, 
                     Hash[ ARGV[2..-1].each_slice(2).map{|n| n.map(&:to_i)} ] )
puts cmd
sendlines(cmd, sp)
#sendlines("03 FD 00", sp)

#t.join
