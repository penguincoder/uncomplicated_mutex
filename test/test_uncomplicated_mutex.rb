require 'redis'
require 'uncomplicated_mutex'
require 'minitest'
require 'minitest/autorun'

class TestUncomplicatedMutex < Minitest::Test
  class SlowObject
    attr_accessor :id
    def initialize
      @id = Time.now.to_i
    end
  end

  def setup
    @obj = SlowObject.new
    @redis = Redis.new
    default_opts = { timeout: 1, ticks: 10, redis: @redis }
    @mutex1 = UncomplicatedMutex.new(@obj, default_opts)
    @mutex2 = UncomplicatedMutex.new(@obj, default_opts)
    @lock_name = @mutex1.lock_name
  end

  def test_mutex_works
    @mutex1.lock do
      assert_equal @redis.exists(@lock_name), true
    end
    assert_equal @redis.exists(@lock_name), false
  end

  def test_sequential_access
    @redis.set('lock:testvalue', 1)
    @mutex1.lock do
      @redis.set('lock:testvalue', 2)
    end
    @mutex2.lock do
      assert_equal(@redis.get('lock:testvalue'), '2')
      @redis.del('lock:testvalue')
    end
    assert_equal @redis.exists('lock:testvalue'), false
  end

  def test_exception_is_thrown
    begin
      @redis.set(@lock_name, 1)
      UncomplicatedMutex.new(@obj, { timeout: 1, fail_on_timeout: true, ticks: 10 }).lock do
        sleep 2
      end
    rescue UncomplicatedMutex::MutexTimeout
      pass "Exception thrown"
    else
      flunk "Exception was not thrown"
    ensure
      @redis.del(@lock_name)
    end
  end

  def test_exception_is_not_thrown
    begin
      @redis.set(@lock_name, 1)
      @mutex2.lock do
        sleep 1.05
      end
    rescue UncomplicatedMutex::MutexTimeout
      flunk "Exception thrown"
    else
      pass "Exception was not thrown"
    ensure
      @redis.del(@lock_name)
    end
  end

  def test_lock_is_not_overwritten
    @mutex1.lock do
      @redis.set(@lock_name, 'abc123')
    end
    assert_equal(@redis.get(@lock_name), 'abc123')
    @redis.del(@lock_name)
  end
end
