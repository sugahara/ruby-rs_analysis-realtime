# -*- coding: utf-8 -*-
module CoralReef
  class Rate
    def initialize()

    end

    def run()
      #puts @crl_rate_command
      gets
      while str = gets
        if str.include?("time") # get time
          time = str.split(" ")[2].to_f
          gets 
          str = gets
          if !str.include?("#") && str != "\n"
            elements = str.split(" ") # get info
            rate_values = {
              :v4pkts => elements[1],
              :v4bytes => elements[2],
              :v6pkts => elements[3],
              :v6bytes => elements[4]
            }
            puts "#{time} #{rate_values[:v4pkts]} #{rate_values[:v4bytes]} #{rate_values[:v6pkts]} #{rate_values[:v6bytes]}"
          else ## no pkt
            puts "#{time} 0 0 0 0"
          end
          STDOUT.flush
        end
      end
    end
  end
end

rate = CoralReef::Rate.new()
rate.run
