require File.expand_path("../rs_analysis.rb",__FILE__)
require File.expand_path("../array.rb",__FILE__)
require File.expand_path("../logger.rb",__FILE__)
require File.expand_path("../error.rb",__FILE__)
require File.expand_path("../timeseries.rb",__FILE__)
require 'net/ssh'
require 'net/scp'
require 'fileutils'
# require 'benchmark'

## Main2
## Timeseries DELTA shift version

class Main2
  STATISTICS_DIR = File.expand_path("../result",__FILE__)
  DELTA = 50
  @data = []
  @timestamp = []
  @file_name = ARGV[0]
  @config = {
    :k_max => 200,
    :k_min => 2,
    :m_c => 50,
    :use_delta_n => true
  }
  hurst_change_logger = RSAnalysis::HurstLogger.new(STATISTICS_DIR+"/#{@file_name}.hurst")
  hurst_change_logger.info("#Number MeanHurst MaxHurst MinHurst")
  ts = Timeseries.new(900)

  data_index = 0
  while str = STDIN.gets do
    next if str.include?("#")
    rate_value = str.split(" ")
    timestamp = rate_value[0]
    data = rate_value[1].to_f
    ts.insert(data, timestamp) 
    if ts.size >= ts.window_size
      @data = ts.to_a[0]
      @timestamp = ts.to_a[1]
      puts time = Time.at(@timestamp[0].to_f)
      @start_time = time.strftime("%Y%m%d-%H:%M:%S")
      
      hurst_logger = RSAnalysis::HurstLogger.new(STDOUT)
      
      rs = RSAnalysis::Analyser.new(@data, data_index, @config)
      rs_result = rs.get_hurst()
      #rs.show_config
      if rs_result != RSAnalysis::Error::HURST_ERROR
        statistics_logger = RSAnalysis::StatisticsLogger.new(STATISTICS_DIR+"/#{@file_name}#{data_index}.rsresult")
        statistics_logger.log_leastsquare_result(rs_result[2])
        statistics_logger.log_statistics(rs_result[1])
        timeseries_logger = RSAnalysis::TimeseriesLogger.new(STATISTICS_DIR+"/#{@file_name}#{data_index}.ts")
        timeseries_logger.log_timeseries(@timestamp,@data)
      else
        puts rs_result
      end


      hurst_logger.info("#Number MeanHurst MaxHurst MinHurst")
      hurst_logger.info("#{@start_time} #{data_index} #{rs_result[0][0]} #{rs_result[0][1]} #{rs_result[0][2]}")

      hurst_change_logger.info("#{@timestamp[0].to_f} #{data_index} #{rs_result[0][0]} #{rs_result[0][1]} #{rs_result[0][2]} #{@start_time}")
      hurst_trans_logger = RSAnalysis::HurstLogger.new(STATISTICS_DIR+"/#{@file_name}#{data_index}.hursttrans")
      #Hurst transition log
      hurst_trans_logger.info("#Range MeanHurst MaxHurst MinHurst")
      rs_result[3].each_with_index do |hurst, i|
        hurst_trans_logger.info("#{i} #{hurst[0]} #{hurst[1]} #{hurst[2]}") if hurst != nil
      end

      remote_dir = "/Users/JunSugahara/temp"
      host = "akimac01.cse.kyoto-su.ac.jp"
      id = "JunSugahara"
      options = {
        :keys => "/home/sugahara/.ssh/sugahara-ruby",
        :passphrase => "sugahara"
      }
      files = []
      files << STATISTICS_DIR+"/#{@file_name}.hurst"
      files << STATISTICS_DIR+"/#{@file_name}#{data_index}.rsresult"
      files << STATISTICS_DIR+"/#{@file_name}#{data_index}.ts"
      files << STATISTICS_DIR+"/#{@file_name}#{data_index}.hursttrans"

      files.each do |name|
        Net::SCP.start(host, id, options) do |scp|
          puts "#{Time.now} uploading file... #{name}"
          scp.upload!("#{name}",remote_dir)
          puts "#{Time.now} uploaded. #{name}"
        end
        #puts "#{Time.now} detele file #{name}"
        #FileUtils.rm("#{name}")
      end

      ts.delete(DELTA)
      data_index += 1
    end
  end

  #  } ##FOR BENCHMARK
end
