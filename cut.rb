require File.join Dir.pwd, 'crap'

Crap.load 'unused.yml'
Crap.cut

require 'mspec/commands/mspec'
script = MSpecMain.new
script.load_default
# script.load '~/.mspecrc'
script.options
script.signals
script.register
script.run
