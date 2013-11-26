class Timeseries

  def initialize(window_size)
    @values = []
    @timestamp = []
    @window_size = window_size
  end

  def insert(value,timestamp)
    @values.push(value)
    @timestamp.push(timestamp)
  end

  def delete(n=0)
    @values.slice!((0...n))
    @timestamp.slice!((0...n))
  end

  def to_a
    return @values[0..@window_size],@timestamp[0..@window_size]
  end

  def size
    @values.size
  end

  def window_size
    @window_size
  end

end
