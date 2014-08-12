require File.join Dir.pwd, 'crap'

Crap.wrap_all
Crap.wrap_dog

require 'mspec/commands/mspec'
script = MSpecMain.new
script.load_default
# script.load '~/.mspecrc'
script.options
script.signals
script.register
script.run

Crap.save 'unused.yml'
