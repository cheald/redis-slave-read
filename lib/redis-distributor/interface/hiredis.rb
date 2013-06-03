class Redis
  module Distributor
    module Interface
      class Hiredis < Base
        slave %w(
          bitcount dbsize debug dump echo exists get getbit getrange hexists hget hgetall hkeys hlen hmget hvals info keys lastsave lindex llen mget object ping pttl
          randomkey scard sismember smembers srandmember strlen sunion time ttl type zcard zcount zrange zrangebyscore zrank zrevrank zrevrangebyscore zrevrank zscore
        )

        master %w(
          append auth bgrewriteaof bgsave bitop blpop brpop brpoplpush client config debug debug decr decrby del eval evalsha expire expireat flushall
          flushdb getset hdel hincrby hincrbyfloat hmset hset hsetnx incr incrby incrbyfloat linsert lpop lpush lpushx lrange lrem lset ltrim migrate monitor move mset
          msetnx persist pexpire pexpireat psetex psubscribe publish punsubscribe quit rename renamenx restore rpop rpoplpush rpush rpushx sadd save script exists
          script flush script kill script load sdiff sdiffstore select set setbit setex setnx setrange shutdown sinter sinterstore slaveof slowlog smove sort spop srem
          subscribe sunionstore sync unsubscribe unwatch watch zadd zincrby zinterstore zrem zremrangebyrank zremrangebyscore zrevrange zunionstore
        )

        all %w(select)

        %w(db= connect disconnect reconnect).each do |method|
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