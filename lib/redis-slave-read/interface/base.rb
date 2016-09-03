require 'redis'
require 'thread'

class Redis
  module SlaveRead
    module Interface
      class Base
        attr_accessor :master, :slaves, :nodes, :read_master, :all

        class << self
          def slave(commands)
            commands.each do |method|
              define_method(method) do |*args|
                next_node.send(method, *args)
              end
            end
          end

          def master(commands)
            commands.each do |method|
              define_method(method) do |*args|
                master.send(method, *args)
              end
            end
          end

          def all(commands)
            commands.each do |method|
              define_method(method) do |*args|
                @all.each do |node|
                  node.send(method, *args)
                end
              end
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
          @index = rand(@nodes.length)
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
            @locked_node = nil
          end
        end

        def multi(*args, &block)
          replies = nil
          @block_exec_mutex.synchronize do
            @locked_node = @master
            replies = @master.send(:multi, *args, &block)
            @locked_node = nil
          end
          replies
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
  end
end
