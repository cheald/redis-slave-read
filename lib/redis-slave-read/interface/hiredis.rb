# frozen_string_literal: true

class Redis
  module SlaveRead
    module Interface
      class Hiredis < Base
        COMMANDS = %w[
          append auth bgrewriteaof bgsave bitcount bitfield bitop bitpos blpop brpop brpoplpush client cluster command config dbsize debug decr decrby del discard dump echo eval evalsha exec exists
          expire expireat flushall flushdb geoadd geodist geohash geopos georadius georadiusbymember get getbit getrange getset hdel hexists hget hgetall hincrby hincrbyfloat hkeys hlen hmget hmset
          hscan hset hsetnx hstrlen hvals incr incrby incrbyfloat info keys lastsave lindex linsert llen lpop lpush lpushx lrange lrem lset ltrim mget migrate monitor move mset msetnx multi object
          persist pexpire pexpireat pfadd pfcount pfmerge ping psetex psubscribe pttl publish pubsub punsubscribe quit randomkey readonly readwrite rename renamenx restore role rpop rpoplpush rpush
          rpushx sadd save scan scard script sdiff sdiffstore select set setbit setex setnx setrange shutdown sinter sinterstore sismember slaveof slowlog smembers smove sort spop srandmember srem
          sscan strlen subscribe sunion sunionstore swapdb sync time touch ttl type unlink unsubscribe unwatch wait watch zadd zcard zcount zincrby zinterstore zlexcount zrange zrangebylex
          zrangebyscore zrank zrem zremrangebylex zremrangebyrank zremrangebyscore zrevrange zrevrangebylex zrevrangebyscore zrevrank zscan zscore zunionstore
        ].freeze

        SLAVE_COMMANDS = %w[
          bitcount bitpos dbsize debug dump echo exists geodist geohash geopos georadius georadiusbymember get getbit getrange hexists hget hgetall hkeys hlen hmget hvals info keys lastsave lindex
          llen mget object ping pttl randomkey scard sismember smembers srandmember strlen sunion time ttl type zcard zcount zrange zrangebyscore zrank zrevrangebyscore zrevrank zrevrank zscore
        ].freeze

        ALL_NODE_COMMANDS = %w[
          select
        ].freeze

        BATCH_COMMANDS = %w[multi pipeline exec discard].freeze

        slave SLAVE_COMMANDS
        all ALL_NODE_COMMANDS
        master COMMANDS - SLAVE_COMMANDS - ALL_NODE_COMMANDS - BATCH_COMMANDS

        %w[db= connect disconnect reconnect].each do |method|
          define_method(method) do |*args|
            all.each do |node|
              node.client.send(method, *args)
            end
          end
        end
      end
    end
  end
end
