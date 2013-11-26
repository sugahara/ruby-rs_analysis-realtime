require 'logger'
require 'readline'

module RSAnalysis
  
  class HurstLogger < Logger
    def initialize(logdev)
      super(logdev)
      self.formatter = proc{|severity, datetime, progname, message|
        "#{message}\n"
      }
    end
  end

  class StatisticsLogger < HurstLogger
    def log_statistics(set_of_log_rs_statistics)
      info("#log(k) rs_statistics rs_statistics_mean")
      set_of_log_rs_statistics[0].each_with_index do |rs_s, i|
        next if rs_s.nil?
        rs_s.each_with_index do |rs,j|
          info("#{Math::log(i)} #{rs} #{set_of_log_rs_statistics[1][i]} #{j}")
        end
      end
    end

    def log_leastsquare_result(result)
      order = ["## Mean", "## Max", "## Min"]
      result.each_with_index do |f,i|
        info(order[i])
        info("#"+"#{f[0]} + #{f[1]}" + " * x")
      end
    end
  end

  class TimeseriesLogger < HurstLogger
    def log_timeseries(data)
      data.each do |d|
        info(d)
      end
    end
  end

end
