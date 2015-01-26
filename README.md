# Redis::SlaveRead

Provides for distribution of slave reads in a Redis cluster.

## Installation

Add this line to your application's Gemfile:

    gem 'redis-slave-read'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install redis-slave-read

## Usage

Rather than using a Redis instance, create a wrapper that wraps multiple Redis connections.

    master = Redis.new "localhost:6379"
    slave1 = Redis.new "localhost:6389"
    slave2 = Redis.new "localhost:6399"
    $redis = Redis::SlaveRead::Interface::Hiredis.new(master: master, slaves: [slave1, slave2])

Make sure that your slaves are set to be slaved to the master, like `slaveof localhost 6379`

Now, you can treat your SlaveRead interface as a normal Redis interfaces. Reads are distributed
among the slaves, and writes are always sent to the master. Writes will be propagated to slaves
by the master.

    $redis.set "foo", "bar"
    $redis.get "foo"

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
