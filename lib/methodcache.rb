require 'benchmark'

class MethodCache
  def initialize obj, name, type, options
    @name        = name
    @type        = type
    @timestamps  = {}
    @values      = {}
    @last_clean  = Time.now
    @clean_every = options[:clean_every] || 10*60
    @duration    = options[:for] || 60
    @warn_time   = options[:warn_time] || 0.03
    @umeth       = obj.instance_method(name)
  end

  def timebox title, max_t = 0.01
    result = nil
    t = Benchmark.realtime{ result = yield }
    warn "#{title}: #{(time*1000).to_i}ms" unless t < max_t
    result
  end

  def to_proc
    cache = self
    proc{ |*params| cache.try(self, *params) }
  end

  def compute?(key, obj, *params)
    ts = @timestamps[key]
    return unless !ts or ts <= Time.now - @duration
    timebox "#{@name}(#{key}) was not cached #{ts} < #{Time.now - @duration}", @warn_time do
      @values[key] = @umeth.bind(obj).call(*params)
      @timestamps[key] = Time.now
    end
    true
  end

  def clean?
    expiry = Time.now - @duration
    return unless @last_clean < Time.now - @clean_every
    @timestamps.keys.each do |key|
      next unless @timestamps[key] < expiry
      @timestamps.delete(key)
      @values.delete(key)
    end
    @last_clean = Time.now
  end

  def try(obj, *params)
    key = (@type == :instance ? params + [obj.id] : params).hash
    compute?(key, obj, *params) and clean?
    @values[key]
  end

  module ModuleExtensions
    def instance_cache name, options = {}
      define_method(name, &MethodCache.new(self, name, :instance, options))
    end

    def singleton_cache name, options = {}
      define_method(name, &MethodCache.new(self, name, :singleton, options))
    end

    def class_cache name, options = {}
      metaclass = (class<<self;self;end)
      cache = MethodCache.new(metaclass, name, :singleton, options)
      metaclass.send(:define_method, name, &cache)
    end

    def module_cache name, options = {}
      class_cache name, options
      singleton_cache name, options
    end

    alias_method :cache, :singleton_cache
  end
end
