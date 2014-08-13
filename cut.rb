require File.join Dir.pwd, 'crap'

Crap::Cleaner.load 'unused.yml'
Crap::Cleaner.clean_all
Crap::Cleaner.clean_dog

# Load your app

def f x
  return 1 if x < 2
  f(x-1) + f(x-2)
end

p f 9
