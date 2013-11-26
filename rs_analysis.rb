# -*- coding: utf-8 -*-
#require 'ruby-debug'
require 'gsl'
require File.expand_path("../error.rb",__FILE__)
module RSAnalysis
  class Analyser
    DEFAULT_CONFIG = {:k_max => 100, :k_min => 2, :m_c => 50, :use_delta_n => false}
    RS_INDEX = 0
    RS_MEAN_INDEX = 1
    RS_MAX_INDEX = 2
    RS_MIN_INDEX = 3
    @@config = {}

    def initialize(data, data_index, config = {})
      @data = data
      @data_index = data_index
      @n = @data.size
      @@config = DEFAULT_CONFIG.dup.update(config)
      # @k_max = @config[:k_max]
      # @k_min = @@config[:k_min]
      @m_c = @@config[:m_c]
      @delta_n = ((@n-@@config[:k_max])/(@m_c-1)).floor
      @max_dup_rate = ((@@config[:k_max]-(@delta_n-1))/@@config[:k_max].to_f)
      if @delta_n < 1.0 && !(@n < @@config[:k_max]) # Error
        show_config
        puts "Invalid configure"
        exit
      end
      @data_sum = [0]
      @data.size.times do |t|
        @data_sum[t+1] = @data_sum[t] + @data[t]
      end

    end

    def calc_delta_n(k)
      @delta_n = ((@n-k)/(@m_c-1)).floor
    end

    def self.get_config()
      @@config
    end

    def show_config
      puts "delta_n:#{@delta_n}"
      puts "n:#{@n}"
      puts "k_min:#{@@config[:k_min]}"
      puts "k_max:#{@@config[:k_max]}"
      puts "m_c:#{@m_c}"
    end

    def v(j)
      v = j - 1
      @data_sum[j]
    end

    def s(n,k)
      avg = (@data_sum[n+k] - @data_sum[n]) / k
      sum = 0
      @data[n...n+k].each do |v|
        sum += (v - avg)**2
      end
      Math::sqrt(sum/k)
    end

    def r(n, k)
      array = []
      for j in 1..k
        array.push v(n+j) - v(n) - j.to_f*(v(n+k.to_f) - v(n))/k.to_f
      end
      r = array.max - array.min
      return r
    end

    def q(n,k)
      r(n,k) / s(n,k)
    end

    def square_fit(x, y, options = {})
      options = {
        :fit => :linear
      }.merge(options)
      case options[:fit]
      when :linear
        c0, c1, cov00, cov01, cov11, chisq, status = GSL::Fit.linear(x, y)
        return [c0, c1]
      when :nonlinear
        # power fit
        coef, err, chi2, dof = GSL::MultiFit::FdfSolver.fit(-x, y, "power")
        # exp fit
        #sigma = GSL::Vector[x.size]
        #sigma.set_all(0.1)
        #coef, err, chi2, dof = GSL::MultiFit::FdfSolver.fit(x, sigma, y, "exponential")
        y0 = coef[0]
        amp = coef[1]
        b = coef[2]
        return [y0, amp, b]
      end
      []
    end

    def k_error_check()
      if @@config[:k_min] >= @@config[:k_max]
        return true
      end
      if @n < @@config[:k_max]
        return true
      end
      false
    end

    def need_delta_n?(k)
      if k <= @n/@m_c
        false
      else
        true
      end
    end

    def calc_rs_statistics()

      if k_error_check() == true
        return RSAnalysis::Error::RS_STATISTICS_ERROR
      end
      rs_statistics = []
      rs_statistics_mean = []
      rs_statistics_max = []
      rs_statistics_min = []
      
      for k in @@config[:k_min]..@@config[:k_max]
        rs_statistic = []
        # @m_c.times do |m|
        m = 0
        n = 0
        loop do
          if need_delta_n?(k) && @@config[:use_delta_n] == true
            calc_delta_n(k)
            n = m * @delta_n
          else
            n = m * k
          end
          break if n+k > @n

          q = q(n,k)
          #if (m == 37 && k == 74)# || (m==39 && k == 200)
          #  puts "s(n,k) = #{s(n,k)}"
          #  puts "r(n,k) = #{r(n,k)}"
          #  puts "r(n,k)/s(n,k) = #{r(n,k)/s(n,k)}"
          #end
          #if (Math::log(q) <= 1.7 && k >= 46) || (Math::log(q) <= 1.3 && k>= 29)
          #if (Math::log(q) >= 2.8 && k==84)
          #if (n..n+k).include?(502)
          #if k == 21 && m==39 || k == 21 && m == 38
          #  puts "#{k} : #{n}〜#{n+k} : #{Math::log(q)} #{m}"
          #  puts "#{Math::log(k)} #{Math::log(q)}"

          #puts "s(n,#{k}) = #{s(n,k)}"
          #puts "r(n,#{k}) = #{r(n,k)}"
          #puts "log(r(n,#{k})/s(n,#{k})) = #{Math::log(r(n,k)/s(n,k))}"
          #puts
          #end
          if q.nan?
            new_config = @@config.update(:k_min => @@config[:k_min]+1)
            return RSAnalysis::Analyser.new(@data, @data_index, new_config).calc_rs_statistics()
          end
          rs_statistic.push q
          m += 1
          #if m >= 40 && k == 200 && m<=50
          #  puts @data[n..n+k]
          #end
          # サンプル数上限のbreak
          break if @@config[:use_delta_n] == true && m >= @@config[:m_c]
        end
        rs_statistics[k] = rs_statistic
        rs_statistics_mean[k] = rs_statistic.avg
        rs_statistics_max[k] = rs_statistic.max
        rs_statistics_min[k] = rs_statistic.min
      end
      return rs_statistics, rs_statistics_mean, rs_statistics_max, rs_statistics_min
    end

    def get_rs_statistics_logarithm(set_of_rs_statistics)
      log_rs_statistics = Array.new(@@config[:k_max]+1)
      log_rs_statistics_mean = []
      log_rs_statistics_min = []
      log_rs_statistics_max = []
      (@@config[:k_min]..@@config[:k_max]).each do |k|
        log_rs_statistics[k] = (set_of_rs_statistics[RS_INDEX][k].inject([]){|result, v| result.push(Math::log(v))})
        log_rs_statistics_mean[k] = Math::log(set_of_rs_statistics[RS_MEAN_INDEX][k])
        log_rs_statistics_max[k] = Math::log(set_of_rs_statistics[RS_MAX_INDEX][k])
        log_rs_statistics_min[k] = Math::log(set_of_rs_statistics[RS_MIN_INDEX][k])
      end
      return log_rs_statistics, log_rs_statistics_mean, log_rs_statistics_max, log_rs_statistics_min
    end

    def get_least_square(set_of_log_rs_statistics, limit = nil)
      x = GSL::Vector.alloc(@@config[:k_max] - @@config[:k_min]+1)
      y = GSL::Vector.alloc(@@config[:k_max] - @@config[:k_min]+1)
      y_max = GSL::Vector.alloc(@@config[:k_max] - @@config[:k_min]+1)
      y_min = GSL::Vector.alloc(@@config[:k_max] - @@config[:k_min]+1)
      if limit == nil
        upper_limit = @@config[:k_max]
      else
        upper_limit = limit
      end
      (@@config[:k_min]..upper_limit).each_with_index do |k, i|
        x[i] = Math::log(k)
        y[i] = set_of_log_rs_statistics[RS_MEAN_INDEX][k]
        y_max[i] = set_of_log_rs_statistics[RS_MAX_INDEX][k]
        y_min[i] = set_of_log_rs_statistics[RS_MIN_INDEX][k]
      end
      options={}
      c0_mean, c1_mean = square_fit(x, y, options)
      c0_max, c1_max = square_fit(x, y_max, options)
      c0_min, c1_min = square_fit(x, y_min, options)
      return [c0_mean, c1_mean], [c0_max, c1_max], [c0_min, c1_min]
    end

    def get_hurst()
      set_of_rs_statistics = calc_rs_statistics()
      if set_of_rs_statistics == RSAnalysis::Error::RS_STATISTICS_ERROR
        return RSAnalysis::Error::HURST_ERROR
      end
      set_of_log_rs_statistics = get_rs_statistics_logarithm(set_of_rs_statistics)

      hurst = get_least_square(set_of_log_rs_statistics)
      hurst_mean = hurst[0][1]
      hurst_max = hurst[1][1]
      hurst_min = hurst[2][1]
      set_of_hurst = [hurst_mean, hurst_max, hurst_min]
      set_of_hurst_trans = Array.new
      (@@config[:k_min]+1..@@config[:k_max]).each do |limit|
        hurst_transitions = get_least_square(set_of_log_rs_statistics, limit)
        set_of_hurst_trans[limit] = [hurst_transitions[0][1], hurst_transitions[1][1], hurst_transitions[2][1]]
      end

      return set_of_hurst, set_of_log_rs_statistics, hurst, set_of_hurst_trans
    end

  end
end
