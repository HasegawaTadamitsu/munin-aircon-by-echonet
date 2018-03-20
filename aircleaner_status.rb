#!/usr/bin/env ruby
# coding: utf-8
require "socket"
require "ipaddr"
require 'bindata'
require 'timeout'
#require "pry" # if you need

class Property2MuninString
  def self.print(property)
    ret = []
    property.each do |val|
      epc =val.epc
      case epc
      when 0x80
        tmp = val.edt[0]
        data = (tmp == 0x30)? 100:0
        ret << "OperationStatus.value #{data}"
      when 0xa0
        val = val.edt[0]
        ret << "AirFlowRateSetting.value #{val}"
      when 0xc0
        tmp = val.edt[0]
        data = (tmp == 0x42)? 10:90
        ret <<  "AirPollutionDetectionStatis.value #{data}"
      else
      end ## end of case
    end  ## end of property each
    return ret
  end ## end of print_debug
end


class PropertyData < BinData::Record
  uint8be  :epc  #Echonet lite  Property count
  uint8be  :pdc  #Property Data count
  array  :edt, :type => :uint8be,  :initial_length => :pdc
end

class BEOJ < BinData::Record
  uint8be  :class_group_code
  uint8be  :class_code
  uint8be  :instance_code
  def set_values a,b,c
    self[:class_group_code] = a
    self[:class_code] = b
    self[:instance_code] = c
  end
end

class EData < BinData::Record
  beoj  :seoj  #source Echonet lite ObJect 
  beoj  :deoj  #dest   Echonet lite ObJect 
  uint8be  :esv  #Echonet lite SerVice
  uint8be  :opc  #Object Property count
  array  :property, :type => :propertyData,  :initial_length => :opc

  ESV_Set_I = 0x60
  ESV_Set_C = 0x61
  ESV_INF_REQ = 0x63
  ESV_Set_Get = 0x6e
  
  def set_values a_seoj,a_deoj,a_esv
    self[:seoj] = a_seoj
    self[:deoj] = a_deoj
    self[:esv]  = a_esv
  end
  def add_property a_property
    before_opc = self[:opc]
    self[:property][before_opc] = a_property
    self[:opc] = before_opc + 1
  end
end

class EchonetData < BinData::Record
  uint8be  :ehd1 # Echonet lite denbun HeaDer1
  uint8be  :ehd2 # Echonet lite denbun HeaDer2
  uint16be :tid  # Trunsaction ID
  eData    :edata #Echonet lite data
  def set_val arg_tid, arg_edata
    self[:ehd1] = 0x10
    self[:ehd2] = 0x81
    self[:tid] = arg_tid
    self[:edata] = arg_edata
  end
end


class Main
  attr_reader :recv_data
  
  def initialize  arg_send_ip, arg_eoj
    @send_ip = arg_send_ip
    @target_eoj = arg_eoj
    
    @udps = UDPSocket.open()
    @udps.bind("0.0.0.0",3610)
    mreq = IPAddr.new("224.0.23.0").hton + IPAddr.new("0.0.0.0").hton
    @udps.setsockopt(Socket::IPPROTO_IP, Socket::IP_ADD_MEMBERSHIP, mreq)
  end

  def execute
    @tid = set_tid_random
    send_data
    return recv_data_loop
  end

  private
  def recv_data_loop
    begin
      Timeout.timeout(3) do 
        3.times  do
          msg =  @udps.recvmsg
          raw_data = msg[0]
          ip_addr = msg[1]
          @recv_data = EchonetData.read( raw_data )
          if  @recv_data[:tid] == @tid and ip_addr.ip_address == @send_ip
            return true
          end
          puts  "recev other data #{ip_addr.ip_address},#{@recv_data[:tid]}"
        end # end of times loop
      end # timeout
    rescue Timeout::Error => e
       # p 'main: timeout', e.backtrace.first
    end
    return false         
  end

  def set_tid_random
    @tid = rand(10000)
  end

  def send_data
    seoj = BEOJ.new
    seoj.set_values 0x05,0xff,0x01

    edata = EData.new
    edata.set_values seoj,@target_eoj,EData::ESV_INF_REQ
    command=%w( 0x80 0xa0 0xc0 )
    command.each do | com |
      property = PropertyData.new
      property[:epc] = com.to_i(16)
      property[:pdc] = 0x00
      edata.add_property property
    end
    
    echonetdata = EchonetData.new
    echonetdata.set_val @tid ,edata
    
    u = UDPSocket.new()
    u.connect(@send_ip,3610)
    # p echonetdata.to_hex
    u.send(echonetdata.to_binary_s,0)
    u.close
  end
end

if ARGV[0] == "config"
  puts "graph_title Aircleaner monitor"
  puts "graph_args --base 1000 -l 0"
  puts "graph_vlabel values"
  puts "graph_category life"
  puts "graph_info Aircleaner monitor by echonet."
  
  puts "OperationStatus.label Operation Status"
  puts "OperationStatus.type GAUGE"
  puts "AirFlowRateSetting.label Air Flow Rate Setting"
  puts "AirFlowRateSetting.type GAUGE"
  puts "AirPollutionDetectionStatis.label Air Pollution Detection Status"
  puts "AirPollutionDetectionStatis.type GAUGE"

  exit 0
end



aircon_eoj = BEOJ.new
aircon_eoj.set_values 0x01,0x35,0x01 #change here
m = Main.new("192.168.33.126",aircon_eoj)
exit 1 if m.execute == false

data = m.recv_data
property = data[:edata][:property]
print_data = Property2MuninString.print property
print_data.each do |val|
  puts val
end
