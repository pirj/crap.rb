require File.join Dir.pwd, 'crap'

def f x
  return 1 if x < 2
  f(x-1) + f(x-2)
end

require 'benchmark'

n = 2000
res = Benchmark.measure do
  n.times { f(20) }
end
p res

Crap::Cleaner.load 'unused.yml'
Crap::Cleaner.clean_all
Crap::Cleaner.clean_dog

res = Benchmark.measure do
  n.times { f(20) }
end
p res
