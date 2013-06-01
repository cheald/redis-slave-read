require "redis-distributor/version"
require 'redis'
require 'thread'

class Redis
  class Distributor
    attr_accessor :master, :slaves, :nodes, :read_master

    SLAVE_COMMANDS = "
      BITCOUNT,DBSIZE,DEBUG,DUMP,ECHO,EXISTS,GET,GETBIT,GETRANGE,HEXISTS,HGET,HGETALL,HKEYS,HLEN,HMGET,HVALS,INFO,KEYS,LASTSAVE,LINDEX,LLEN,MGET,OBJECT,
      PING,PTTL,RANDOMKEY,SCARD,SISMEMBER,SMEMBERS,SRANDMEMBER,STRLEN,SUNION,TIME,TTL,TYPE,ZCARD,ZCOUNT,ZRANGE,ZRANGEBYSCORE,ZRANK,ZREVRANK,ZREVRANGEBYSCORE,
      ZREVRANK,ZSCORE
    ".downcase.split(",").map(&:strip)

    MASTER_COMMANDS = "
      APPEND, AUTH, BGREWRITEAOF, BGSAVE, BITCOUNT, BITOP, BLPOP, BRPOP, BRPOPLPUSH, CLIENT, CONFIG, CONFIG, DBSIZE, DEBUG OBJECT, DEBUG SEGFAULT, DECR, DECRBY, DEL, DISCARD, DUMP, ECHO, EVAL, EVALSHA, EXEC, EXISTS, EXPIRE,
      EXPIREAT, FLUSHALL, FLUSHDB, GET, GETBIT, GETRANGE, GETSET, HDEL, HEXISTS, HGET, HGETALL, HINCRBY, HINCRBYFLOAT, HKEYS, HLEN, HMGET, HMSET, HSET,
      HSETNX, HVALS, INCR, INCRBY, INCRBYFLOAT, INFO, KEYS, LASTSAVE, LINDEX, LINSERT, LLEN, LPOP, LPUSH, LPUSHX, LRANGE, LREM, LSET, LTRIM, MGET, MIGRATE,
      MONITOR, MOVE, MSET, MSETNX, MULTI, OBJECT, PERSIST, PEXPIRE, PEXPIREAT, PING, PSETEX, PSUBSCRIBE, PTTL, PUBLISH, PUNSUBSCRIBE, QUIT, RANDOMKEY,
      RENAME, RENAMENX, RESTORE, RPOP, RPOPLPUSH, RPUSH, RPUSHX, SADD, SAVE, SCARD, SCRIPT EXISTS, SCRIPT FLUSH, SCRIPT KILL, SCRIPT LOAD, SDIFF, SDIFFSTORE,
      SELECT, SET, SETBIT, SETEX, SETNX, SETRANGE, SHUTDOWN, SINTER, SINTERSTORE, SISMEMBER, SLAVEOF, SLOWLOG, SMEMBERS, SMOVE, SORT, SPOP, SRANDMEMBER, SREM,
      STRLEN, SUBSCRIBE, SUNION, SUNIONSTORE, SYNC, TIME, TTL, TYPE, UNSUBSCRIBE, UNWATCH, WATCH, ZADD, ZCARD, ZCOUNT, ZINCRBY, ZINTERSTORE, ZRANGE,
      ZRANGEBYSCORE, ZRANK, ZREM, ZREMRANGEBYRANK, ZREMRANGEBYSCORE, ZREVRANGE, ZREVRANGEBYSCORE, ZREVRANK, ZSCORE, ZUNIONSTORE
    ".downcase.split(",").map(&:strip) - SLAVE_COMMANDS

    ALL_COMMANDS = "select".downcase.split(",").map(&:strip)
    ALL_CLIENT_COMMANDS = "db=, connect, disconnect, reconnect".downcase.split(",").map(&:strip)

    SLAVE_COMMANDS.each do |method|
      define_method(method) do |*args|
        next_node.send(method, *args)
      end
    end

    MASTER_COMMANDS.each do |method|
      define_method(method) do |*args|
        master.send(method, *args)
      end
    end

    ALL_COMMANDS.each do |command|
      define_method(command) do |*args|
        @all.each do |node|
          node.send(command, *args)
        end
      end
    end

    ALL_CLIENT_COMMANDS.each do |command|
      define_method(command) do |*args|
        @all.each do |node|
          node.client.send(command, *args)
        end
      end
    end

    def initialize(options = {})
      @block_exec_mutex = Mutex.new
      @round_robin_mutex = Mutex.new
      @master = options[:master] || raise("Must specify a master")
      @slaves = options[:slaves] || []
      @read_master = options[:read_master].nil? && true || options[:read_master]
      @all = slaves + [@master]
      @nodes = slaves.dup
      @nodes.unshift @master if @read_master
      @index = 0
    end

    def method_missing(method, *args)
      if master.respond_to?(method)
        define_method(method) do |*_args|
          @master.send(method, *_args)
        end
        send(method, *args)
      else
        super
      end
    end

    def pipelined(*args, &block)
      @block_exec_mutex.synchronize do
        @locked_node = @master
        @master.send(:pipelined, *args, &block)
      end
    end

    def exec(*args)
      @block_exec_mutex.synchronize do
        @locked_node = nil
        @master.send(:exec, *args)
      end
    end

    def discard(*args)
      @block_exec_mutex.synchronize do
        @locked_node = nil
        @master.send(:discard, *args)
      end
    end

    def multi(*args, &block)
      @block_exec_mutex.synchronize do
        @locked_node = @master
        @master.send(:multi, *args, &block)
      end
    end

    private

    def next_node
      @round_robin_mutex.synchronize do
        if @locked_node
          @locked_node
        else
          @index = (@index + 1) % @nodes.length
          @nodes[@index]
        end
      end
    end
  end
end
