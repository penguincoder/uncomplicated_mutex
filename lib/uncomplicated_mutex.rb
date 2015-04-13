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
    @redis            = opts[:redis] || Redis.new
    @lock_name        = "lock:#{obj.class.name}:#{obj.id}".squeeze(":")
    @token            = Digest::MD5.new.hexdigest("#{@lock_name}_#{Time.now.to_f}")
    set_expiration_time
  end

  def acquire_mutex
    puts("Running transaction to acquire the lock #{@lock_name}") if @verbose
    @redis.eval(LUA_ACQUIRE, [ @lock_name ], [ @timeout, @token ]) == 1
  end

  def current_token_value
    @redis.get(@lock_name)
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

  def recurse_until_ready(depth = 1)
    return false if time_has_expired
    @initial_token = current_token_value if depth == 1
    wait_a_tick if depth > 1
    acquire_mutex || recurse_until_ready(depth + 1)
  end

  def release_mutex
    puts("Releasing the lock #{@lock_name} if it still holds the value '#{@token}'") if @verbose
    @redis.eval(LUA_RELEASE, [ @lock_name ], [ @token ])
  end

  def same_token_as_before
    new_token = current_token_value
    if new_token == @initial_token
      true
    else
      @initial_token = new_token
      false
    end
  end

  def set_expiration_time
    @expiration_time = Time.now.to_i + @timeout
  end

  def time_has_expired
    if Time.now.to_i > @expiration_time
      if same_token_as_before
        true
      else
        set_expiration_time
        false
      end
    else
      false
    end
  end

  def wait_a_tick
    sleep_time = rand(100).to_f / 100.0
    puts("Sleeping #{sleep_time} for the lock #{@lock_name} to become available") if @verbose
    sleep(sleep_time)
  end

  def wait_for_mutex
    if recurse_until_ready
      puts("Acquired lock #{@lock_name}") if @verbose
    else
      puts("Failed to acquire the lock") if @verbose
      raise MutexTimeout.new("Failed to acquire the lock")
    end
  end
end
