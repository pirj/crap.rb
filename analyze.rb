require File.join Dir.pwd, 'crap'

Crap::Analyzer.wrap_all
Crap::Analyzer.wrap_dog

# Do something, e.g. run specs

def f x
  return 1 if x < 2
  f(x-1) + f(x-2)
end

require 'benchmark'
n = 100
res = Benchmark.measure do
  n.times { f(5) }
end

Crap::Analyzer.save 'unused.yml'
