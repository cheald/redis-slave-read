# frozen_string_literal: true

require 'connection_pool'

module ActiveSupport
  module Cache
    class RedisStoreSlaveRead < Store
      def initialize(options = {})
        @options = options.dup
        @pool_options = @options.slice!(*ActiveSupport::Cache::UNIVERSAL_OPTIONS)
        init_pool(@pool_options)
      end

      def write(name, value, options = nil)
        options = merged_options(options)
        instrument(:write, name, options) do |_payload|
          entry = options[:raw].present? ? value : Entry.new(value, options)
          write_entry(namespaced_key(name, options), entry, options)
        end
      end

      # Delete objects for matched keys.
      #
      # Example:
      #   cache.del_matched "rab*"
      def delete_matched(matcher, options = nil)
        options = merged_options(options)
        instrument(:delete_matched, matcher.inspect) do
          matcher = key_matcher(matcher, options)
          begin
            @pool.with { |s| !(keys = s.keys(matcher)).empty? && s.del(*keys) }
          rescue Errno::ECONNREFUSED
            false
          end
        end
      end

      # Reads multiple keys from the cache using a single call to the
      # servers for all keys. Options can be passed in the last argument.
      #
      # Example:
      #   cache.read_multi "rabbit", "white-rabbit"
      #   cache.read_multi "rabbit", "white-rabbit", :raw => true
      def read_multi(*names)
        values = @pool.with { |s| s.mget(*names) }

        # Remove the options hash before mapping keys to values
        names.extract_options!

        result = Hash[names.zip(values)]
        result.reject! { |_k, v| v.nil? }
        result
      end

      # Increment a key in the store.
      #
      # If the key doesn't exist it will be initialized on 0.
      # If the key exist but it isn't a Fixnum it will be initialized on 0.
      #
      # Example:
      #   We have two objects in cache:
      #     counter # => 23
      #     rabbit  # => #<Rabbit:0x5eee6c>
      #
      #   cache.increment "counter"
      #   cache.read "counter", :raw => true      # => "24"
      #
      #   cache.increment "counter", 6
      #   cache.read "counter", :raw => true      # => "30"
      #
      #   cache.increment "a counter"
      #   cache.read "a counter", :raw => true    # => "1"
      #
      #   cache.increment "rabbit"
      #   cache.read "rabbit", :raw => true       # => "1"
      def increment(key, amount = 1)
        instrument(:increment, key, amount: amount) do
          @pool.with { |s| s.incrby(key, amount) }
        end
      end

      # Decrement a key in the store
      #
      # If the key doesn't exist it will be initialized on 0.
      # If the key exist but it isn't a Fixnum it will be initialized on 0.
      #
      # Example:
      #   We have two objects in cache:
      #     counter # => 23
      #     rabbit  # => #<Rabbit:0x5eee6c>
      #
      #   cache.decrement "counter"
      #   cache.read "counter", :raw => true      # => "22"
      #
      #   cache.decrement "counter", 2
      #   cache.read "counter", :raw => true      # => "20"
      #
      #   cache.decrement "a counter"
      #   cache.read "a counter", :raw => true    # => "-1"
      #
      #   cache.decrement "rabbit"
      #   cache.read "rabbit", :raw => true       # => "-1"
      def decrement(key, amount = 1)
        instrument(:decrement, key, amount: amount) do
          @pool.with { |s| s.decrby(key, amount) }
        end
      end

      # Clear all the data from the store.
      def clear
        instrument(:clear, nil, nil) do
          @pool.with(&:flushdb)
        end
      end

      def stats
        @pool.with(&:info)
      end

      # Force client reconnection, useful for apps deployed on forking servers.
      def reconnect
        init_pool(@pool_options)
      end

      def expire(key, expiry)
        @pool.with { |s| s.expire(key, expiry) }
      end

      protected

      def init_pool(options)
        interface = options.fetch(:interface, ::Redis::SlaveRead::Interface::Hiredis)
        @pool&.shutdown { |node| node.disconnect }
        @pool = ConnectionPool.new(size: options.fetch(:pool_size, 1), timeout: options.fetch(:pool_timeout, 3)) do
          interface.new(
            master: ::Redis::Store::Factory.create(options[:master]),
            slaves: options[:slaves].map { |s| ::Redis::Store::Factory.create(s) },
            read_master: options.key?(:read_master) ? options[:read_master] : false
          )
        end
      end

      def write_entry(key, entry, options)
        method = options && options[:unless_exist] ? :setnx : :set
        @pool.with { |s| s.send(method, key, entry, options) }
      rescue Errno::ECONNREFUSED
        false
      end

      def read_entry(key, options)
        entry = @pool.with { |s| s.get(key, options) }
        if entry
          entry.is_a?(ActiveSupport::Cache::Entry) ? entry : ActiveSupport::Cache::Entry.new(entry)
        end
      rescue Errno::ECONNREFUSED
        nil
      end

      ##
      # Implement the ActiveSupport::Cache#delete_entry
      def delete_entry(key, _options)
        @pool.with { |s| s.del(key) }
      rescue Errno::ECONNREFUSED
        false
      end

      # Add the namespace defined in the options to a pattern designed to match keys.
      #
      # This implementation is __different__ than ActiveSupport:
      # __it doesn't accept Regular expressions__, because the Redis matcher is designed
      # only for strings with wildcards.
      def key_matcher(pattern, options)
        prefix = options[:namespace].is_a?(Proc) ? options[:namespace].call : options[:namespace]
        if prefix
          raise "Regexps aren't supported, please use string with wildcards." if pattern.is_a?(Regexp)
          "#{prefix}:#{pattern}"
        else
          pattern
        end
      end
    end
  end
end
