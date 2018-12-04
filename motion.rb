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


sp = SerialPort.new(ARGV[0], 115200, 8, 1, SerialPort::EVEN) # 9600bps, 8bit, stopbit 1, parity none

# 1文字UARTから読んで0xFFみたいな書式で出力
def getc_and_print(sp)
  print "Enter"
  c = sp.getc.unpack(?C).first
  print "0x%X " % c
  c
end

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
    break if not @buf.nil? and @buf.pack("C*").include? "POI"
  end
}

trap(:INT){ t.kill }

# greeting motion with checksum (last byte)
#09 00 02 00 00 00 00 00 0B
#11 00 02 02 00 00 4B 04 00 00 00 00 00 00 00 00 64
#07 0C 80 0B 00 00 9E
#09 00 02 00 00 00 03 00 0E

# モーションアドレス
#          挨拶  挨拶2
address = [2944, 15232]
i       = ARGV[1].to_i

sendlines("""
09 00 02 00 00 00 00 00
11 00 02 02 00 00 4B 04 00 00 00 00 00 00 00 00
07 0C #{[address[i]].pack("S").unpack("C*").map{|n| "%02X" % n}.join(" ")} 00 00
09 00 02 00 00 00 03 00
""", sp)

t.join
puts "POI"
