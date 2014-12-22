Gem::Specification.new do |s|
  s.name        = 'uncomplicated-mutex'
  s.version     = '1.0.0'
  s.date        = '2014-12-22'
  s.summary     = 'Redis. Lua. Mutex.'
  s.description = 'A mutex that uses Redis that is also not complicated.'
  s.authors     = [ 'Andrew Coleman' ]
  s.email       = 'penguincoder@gmail.com'
  s.files       = [ 'lib/uncomplicated_mutex.rb' ]
  s.homepage    = 'https://github.com/penguincoder/uncomplicated_mutex'
  s.license     = 'MIT'

  s.add_runtime_dependency 'redis', '~> 3.0'
  s.add_development_dependency 'minitest', '~> 5.0'
end