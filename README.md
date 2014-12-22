Uncomplicated Mutex
===================

A transactional mutex based in Redis for Ruby. It works across processes, threads, and machines provided you can all access the same Redis server.

This is subtely different from two related projects here on Github: kenn/redis-mutex and dv/redis-semaphore

RedisMutex uses a polling interval and raises an exception on lock timeout. RedisSemaphore uses `blpop` to wait until a value is pushed into a list. I have noticed several issues with the two approaches. I have had jobs continue to run for days with RedisSemaphore due to random and unknown failures. RedisMutex raises an exception, and in my situation, I do not need an exception, I would prefer to assume that the previous job has failed and that execution should continue.

Major Features
==============

* Uses your own Redis or Redis::Namespace instance
* Uses Redis `SET` using Lua transactions based on documentation from http://redis.io/commands/SET for a simple locking pattern.
* It can either _pessimistically_ or _optimistically_ fail. In other words, it will raise an exception if you want and ignore the timeout and continue to run otherwise.
* It uses a fixed number of ticks (or cycles) of wait that are calculated on initialization.
* A lock will not overwrite a value in Redis if the value was changed from the lock's "secret" token.
* It requires that objects to be locked respond to the method `id`.

I take many feathers from the cap of Martin Fowler when I wrote this gem. Once initialized, variables contents never change. Methods are not longer than 10 lines. Method names are very specific yet not too long. Methods are alphabetized in the class definition (except the initializer). Tests are included.

Usage
=====

A number of options are available on initialization:

|Option|Default value|Description|
|fail_on_timeout|`false`|Raise an exception if mutex lock is not acquired in the requested time|
|redis|`Redis.new`  Redis connection to use|
|ticks|`100`|Number of times to wait during the timeout period|
|timeout|`300`|Time, in seconds, to wait until lock is considered stale|
|verbose|`false`|Prints debugging statements|

```
mutex = UncomplicatedMutex.new(my_obj, opts)

mutex.lock do
  my_obj.long_synchronized_process
end
```

This pattern works very well in Sidekiq or Resque. Also, if you need to access the name of the lock for your own value checking, you may ask the mutex `lock_name` to get the actual Redis key of the lock.

Locking Algorithm
=================

* Set value in Redis if it does not exist
* If it exists, wait up to 100 times until :timeout has been met
* Pessimistically throw an exception if lock was not released and configured to do so
* Overwrite existing token with new value and assume ownership if configured to do so
* Run block of code
* Release lock if it contains the same value that it was set to
