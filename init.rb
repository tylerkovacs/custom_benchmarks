require 'custom_benchmarks'
ActionController::Base.send :include, ActionController::CustomBenchmarking

# ADAPTERS

# MemCache Client
# Uncomment the require line below and add the following custom_benchmark
# declaration to application.rb to enabled the memcache-client adapter:
# custom_benchmark {|runtime| MemCache.cache_runtime(runtime) }
require 'adapters/memcache-client'
