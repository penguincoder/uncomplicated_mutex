require 'digest/md5'
require 'redis'

class UncomplicatedMutex
  attr_reader :lock_name

  MutexTimeout = Class.new(StandardError)

  LUA_ACQUIRE = "return redis.call('SET', KEYS[1], ARGV[2], 'NX', 'EX', ARGV[1]) and redis.call('expire', KEYS[1], ARGV[1]) and 1 or 0"
  LUA_RELEASE = "if redis.call('get', KEYS[1]) == ARGV[1] then return redis.call('del', KEYS[1]) else return 0 end"

  def initialize(obj, opts = {})
    @verbose          = opts[:verbose]
    @timeout          = opts[:timeout] || 300
    @fail_on_timeout  = opts[:fail_on_timeout]
    @ticks            = opts[:ticks] || 100
    @wait_tick        = @timeout.to_f / @ticks.to_f
    @redis            = opts[:redis] || Redis.new
    @lock_name        = "lock:#{obj.class.name}:#{obj.id}".squeeze(":")
    @token            = Digest::MD5.new.hexdigest("#{@lock_name}_#{Time.now.to_f}")
  end

  def acquire_mutex
    puts("Running transaction to acquire the lock #{@lock_name}") if @verbose
    @redis.eval(LUA_ACQUIRE, [ @lock_name ], [ @timeout, @token ]) == 1
  end

  def destroy_mutex
    puts("Destroying the lock #{@lock_name}") if @verbose
    @redis.del(@lock_name)
  end

  def lock(&block)
    begin
      wait_for_mutex
      yield block
    ensure
      release_mutex
    end
  end

  def overwrite_mutex
    puts("Replacing the lock #{@lock_name} with #{@token}") if @verbose
    @redis.set(@lock_name, @token)
  end

  def recurse_until_ready(depth = 1)
    return false if depth == @ticks
    wait_a_tick if depth > 1
    acquire_mutex || recurse_until_ready(depth + 1)
  end

  def release_mutex
    puts("Releasing the lock #{@lock_name} if it still holds the value '#{@token}'") if @verbose
    @redis.eval(LUA_RELEASE, [ @lock_name ], [ @token ])
  end

  def wait_a_tick
    puts("Sleeping #{@wait_tick} for the lock #{@lock_name} to become available") if @verbose
    sleep(@wait_tick)
  end

  def wait_for_mutex
    if recurse_until_ready
      puts("Acquired lock #{@lock_name}") if @verbose
    else
      puts("Failed to acquire the lock") if @verbose
      raise MutexTimeout.new("Failed to acquire the lock") if @fail_on_timeout
      overwrite_mutex
    end
  end
end
