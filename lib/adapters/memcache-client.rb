# Add this line to your ApplicationController (app/controllers/application.rb)
# to enable logging for memcache-client:
# custom_benchmark {|runtime| MemCache.cache_runtime(runtime) }

class MemCache
  @@record_size = false
  @@logger = nil
  @@error_logger = nil
  @@cache_latency = 0.0
  @@cache_gets = 0
  @@cache_sets = 0
  @@cache_deletes = 0
  @@cache_hits = 0
  @@cache_misses = 0
  @@get_data_size = 0
  @@set_data_size = 0

  cattr_accessor :record_size, :logger, :error_logger

  def self.reset_benchmarks
    @@cache_latency = 0.0
    @@cache_gets = 0
    @@cache_sets = 0
    @@cache_deletes = 0
    @@cache_hits = 0
    @@cache_misses = 0
    @@get_data_size = 0
    @@set_data_size = 0
  end

  def self.get_benchmarks
    [@@cache_latency, @@cache_gets, @@get_data_size, @@cache_sets, @@set_data_size, @@cache_deletes, @@cache_hits, @@cache_misses]
  end

  def self.cache_runtime(runtime)
    latency,gets,gsize,sets,ssize,deletes,hits,misses = self.get_benchmarks

    # Since we're using memcache store, the reset_benchmarks method call must
    # appear at the beginning of the the request.  This is necessary before
    # Rails saves the session to the store after the entry is written to
    # production.log.  If you don't clear the MemCache stats at the beginning
    # of the request, then the session save from other requests pollutes the
    # cache stats for the subsequent requests.  Use a before_filter in
    # application.rb:
    #   before_filter { MemCache.reset_benchmarks }
    # If you aren't using memcache session store then you uncomment this line:
    # self.reset_benchmarks

    " | memcache: #{sprintf("%.5f,%d,%d,%d,%d,%d,%d,%d",latency,gets,gsize,sets,ssize,deletes,hits,misses)} (#{sprintf("%d", (latency * 100) / runtime)}%)"
  end

  def rescue_no_connection
    begin
      yield
    rescue MemCache::MemCacheError => err
      @@error_logger.info([Time.now.to_s, err.message, err.backtrace].compact.join("\n")) if @@error_logger
      if err.message != "No connection to server" and err.message !~ /^lost connection/i and ENV['RAILS_ENV'] != 'development'
        SystemNotifier.deliver_non_controller_exception_notification(err)
      end
      return nil
    end
  end

  def get_with_benchmark(key, raw=false)
    val = nil
    t1 = Time.now
    val = rescue_no_connection { get_without_benchmark(key, raw) }
    val.nil? ? (@@cache_misses += 1) : (@@cache_hits += 1)
    @@cache_latency += Time.now - t1
    @@cache_gets += 1
    size = @@record_size ? (Marshal.dump(val).length rescue 0) : 0
    @@get_data_size += size if @@record_size
    @@logger.info("MEMCACHE GET #{key} SIZE #{size} TIME #{Time.now - t1}") if @@logger
    val
  end
  alias_method :get_without_benchmark, :get
  alias_method :get, :get_with_benchmark
  alias [] get_with_benchmark

  def get_multi_with_benchmark(*keys)
    val = nil
    t1 = Time.now
    vals = rescue_no_connection { get_multi_without_benchmark(keys) }
    @@cache_latency += Time.now - t1
    @@cache_gets += 1
    if @@logger or @@record_size
      request_id = t1.to_f.to_s.last(4)
      for key in keys
        size = @@record_size ? (Marshal.dump(vals[key]).length rescue 0) : 0
        @@get_data_size += size if @@record_size
        @@logger.info("MEMCACHE GETMULTI ID #{request_id} KEY #{key} SIZE #{size} TIME #{Time.now - t1}") if @@logger
      end
    end
    vals
  end
  alias_method :get_multi_without_benchmark, :get_multi
  alias_method :get_multi, :get_multi_with_benchmark

  def set_with_benchmark(key, val, expiry=0, raw=false)
    t1 = Time.now
    rescue_no_connection { set_without_benchmark(key, val, expiry, raw) }
    @@cache_latency += Time.now - t1
    @@cache_sets += 1
    size = @@record_size ? (Marshal.dump(val).length rescue 0) : 0
    @@set_data_size += size if @@record_size
    @@logger.info("MEMCACHE SET #{key} SIZE #{size} TIME #{Time.now - t1}") if @@logger
  end
  alias_method :set_without_benchmark, :set
  alias_method :set, :set_with_benchmark
  alias []= set_with_benchmark

  def add_with_benchmark(key, val, expiry=0, raw=false)
    t1 = Time.now
    rescue_no_connection { add_without_benchmark(key, val, expiry, raw) }
    @@cache_latency += Time.now - t1
    @@cache_sets += 1
    size = @@record_size ? (Marshal.dump(val).length rescue 0) : 0
    @@set_data_size += size if @@record_size
    @@logger.info("MEMCACHE ADD #{key} SIZE #{size} TIME #{Time.now - t1}") if @@logger
  end
  alias_method :add_without_benchmark, :add
  alias_method :add, :add_with_benchmark

  def delete_with_benchmark(key, expiry=0)
    t1 = Time.now
    rescue_no_connection { delete_without_benchmark(key, expiry) }
    @@cache_latency += Time.now - t1
    @@cache_deletes += 1
    @@logger.info("MEMCACHE DELETE #{key} TIME #{Time.now - t1}") if @@logger
  end
  alias_method :delete_without_benchmark, :delete
  alias_method :delete, :delete_with_benchmark
end

