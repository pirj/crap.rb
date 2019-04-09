# Remove unused methods from Ruby Objects in a batch, with pre-analyzer

Does just what title says

## Rationale

Blind attempt at making Ruby faster

## Usage

### Analysis

If you're laze, just run:

    $ ruby analyze.rb

Or:

    # Requires main file
    require 'crap.rb'

    # Wraps all loaded classes so we can understand were their methods ever called
    Crap::Analyzer.wrap_all
    # Watch all loaded classes
    Crap::Analyzer.wrap_dog

    # Do something important and valuable, e.g. run specs or download cat pics

    # Save all unused crap to yaml file so we can load it later
    Crap::Analyzer.save 'unused.yml'

### Treatment

If you're laze, just run:

    $ ruby cut.rb

Or:

    # Requires main file
    require 'crap.rb'

    # Load methods known to be unused
    Crap::Cleaner.load 'unused.yml'
    Crap::Cleaner.clean_all
    # Crap::Cleaner.clean_dog

## Is it any good?

Yes. Absolutely must have.

If you're just curious:

    $ wc -l unused.yml
    649 unused.yml

About 600 unused methods in 60 classes just for a simple benchmark measuring factorial computation speed. And it grows bigger once you do more.

## TODO

Cut those constants were never const\_get'ten?

## Author

Created by [Phil Pirozhkov](https://github.com/pirj)

## Future

Forsee no future
