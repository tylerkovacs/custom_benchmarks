# Custom Benchmarks
#
# Custom Benchmarks allow you to easily log your own information to the
# rails log at the end of each request.  The standard rails summary log
# line looks like this:
#
# Completed in 5ms (View: 3, DB: 2) | 200 OK [http://zvm/]
#
# With custom_benchmarks, an additional line is added to the output that
# contains as many metrics as you like for each request.  e.g.,
#
# Completed in 5ms (View: 3, DB: 2) | 200 OK [http://zvm/]
# Finished WelcomeController#index in 0.08545 (11 reqs/sec) DB: 2 | PID: 30796 | Time: 1233202720 | 200 OK [http://zvm/]
#
# Typically, the log line includes the latency associated with executing
# specific parts of a request.  In the example above, we have added a
# measurement of search latency.  But you can use Custom Benchmarks to add
# any information to the log line.  The example above also shows the ID of
# the process (PID) that served this request.  The PID is useful when parsing
# information from logs that contain data from multiple processes.
#
# Simple Example: Logging the Process ID
#
# To add the PID as a custom benchmark field, simply add a custom_benchmark
# line like the following to your ApplicationController:
#
# class ApplicationController < ActionController::Base
#   custom_benchmark {|runtime| " | PID: #{$$}" }
#   ...
# end
#
# Declare your custom_benchmark with a block that expects an input parameter
# called runtime.  runtime, which isn't used in this example, contains the
# overall latency of the entire request.  Later, we'll show you an example
# of using runtime to calculate percentage latency below.  custom_benchmark
# expects your block to return a string - which will be inserted in the
# log file immediate before the status (e.g., 200 OK [http://www.zvents.com/])
#
# Complex Example: Logging Arbitrary Latency
#
# Let's say that your application includes a search function that is powered
# by Lucene.  Like SQL calls issued to a database, calls to Lucene can take
# a while so you want to log your search latency.
#
# The first step is to set up a mechanism that allows you to record your
# search latency for each request.  You can do that with something like this:
#
# class MySearch
#   @@latency = 0.0
#   cattr_accessor :latency
#
#   def run_search
#     @@latency = Benchmark::measure{
#       # execute the call to Lucene here
#     }.real
#   end
#
#   def self.get_timing_summary(runtime)
#     summary = " | Search: #{sprintf("%.5f",@@latency)} (#{sprintf("%d", (@@latency * 100) / runtime)}%)"
#     @@latency = 0.0
#     summary
#   end
# end
#
# The run_search method uses Benchmark::measure to record the latency of the
# search.  The get_timing_summary class method, which will be invoked by
# a custom_benchmark, returns a formatted string summarizing the search
# latency in absolute and percentage terms.  It also resets the value
# of @@latency to avoid affecting subsequent queries.
#
# Finally, we just need to add a custom_benchmark statement to the
# ApplicationController:
#
# custom_benchmark {|runtime| MySearch.get_timing_summary(runtime) }

module ActionController #:nodoc:
  module CustomBenchmarking #:nodoc:
    def self.included(base)
      base.extend(ClassMethods)

      #if ENV['RAILS_ENV'] != "test"
        base.class_eval do
          alias_method :perform_action_without_custom_benchmark, :perform_action
          alias_method :perform_action, :perform_action_with_custom_benchmark
        end
      #end
    end

    module ClassMethods
      def custom_benchmark(*benchmark, &block)
        #return if ENV['RAILS_ENV'] == "test"

        if block_given?
          write_inheritable_attribute(:custom_benchmarks,
            (read_inheritable_attribute(:custom_benchmarks) || []) << block)
        end
      end

      def custom_benchmarks
        @custom_benchmarks ||= read_inheritable_attribute(:custom_benchmarks) || []
      end
    end

    def perform_action_with_custom_benchmark
      unless logger
        perform_action_without_custom_benchmark
      else
        t1 = Time.now
        perform_action_without_custom_benchmark
        runtime = Time.now - t1

        log_message  = ["Finished #{controller_class_name}\##{action_name} in #{sprintf("%.5f", runtime)} (#{(1 / runtime).floor} reqs/sec)"]
        if Object.const_defined?("ActiveRecord") && ActiveRecord::Base.connected?
          log_message << active_record_runtime
        end
        log_message << rendering_runtime(runtime) if @rendering_runtime
        self.class.custom_benchmarks.each do |benchmark|
          log_message << benchmark.call(runtime)
        end
        log_message << "| Time: #{Time.now.to_i}"
        log_message << "| #{headers["Status"]}"
        log_message << "[#{complete_request_uri rescue "unknown"}]"
        logger.info(log_message.join(' '))
      end
    end
  end
end

module ActiveRecord
  module ConnectionAdapters # :nodoc:
    class AbstractAdapter
      def initialize(connection, logger = nil) #:nodoc:
        @connection, @logger = connection, logger
        @runtime = 0
        @total_runtime = 0
        @last_verification = 0
      end

      def reset_runtime(reset=false) #:nodoc:
        if reset
          rt, @runtime, @total_runtime = @total_runtime, 0, 0
        else
          rt, @runtime = @runtime, 0, 0
        end

        rt
      end

      protected
        def log(sql, name)
          if block_given?
            if @logger and @logger.level <= Logger::INFO
              result = nil
              seconds = Benchmark.realtime { result = yield }
              @runtime += seconds
              @total_runtime += seconds
              log_info(sql, name, seconds)
              result
            else
              seconds = Benchmark.realtime { result = yield }
              @runtime += seconds
              @total_runtime += seconds
              result
            end
          else
            log_info(sql, name, 0)
            nil
          end
        rescue Exception => e
          # Log message and raise exception.
          # Set last_verfication to 0, so that connection gets verified
          # upon reentering the request loop
          @last_verification = 0
          message = "#{e.class.name}: #{e.message}: #{sql}"
          log_info(message, name, 0)
          raise ActiveRecord::StatementInvalid, message
        end
    end
  end
end
