# -*- coding: utf-8 -*-

#-- default requires.
require 'find'
require 'yaml'
require 'time'
require 'logger'
require 'active_record'
require 'active_support'

module Satellite
  module Base
    #-- debug flag.
    DebugMode = ARGV.include?( '-debug' ) || ARGV.include?( '-d' )
    #-- logger
    class StaticLogger
      def initialize! log
        path, age, size = log.values
        @logger = Logger.new( absolute( path ), age, size )
        @logger.formatter = proc { | severity, datetime, progname, message |
          "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}][#{severity}] #{message}\n"
        }
      end
      def level lv
        @logger.level = lv if @logger
      end
      def info message
        write 'INFO', message
        @logger.info( message ) if @logger
      end
      def warn message
        write 'WARN', message
        @logger.warn( message ) if @logger
      end
      def error message
        write 'ERROR', message
        @logger.error( message ) if @logger
      end
      def fatal message
        write 'FATAL', message
        @logger.fatal( message ) if @logger
      end
      def debug message
        write 'DEBUG', message
        @logger.debug( message ) if @logger
      end
      def system message
        write 'system', message
        if @logger
          if DebugMode
            @logger.debug( '[system] ' + message )
          else
            @logger.info( '[system] ' + message )
          end
        end
      end
      def exception exc
        error( exc.message + '\n' + exc.backtrace.to_s )
      end
      def write type, message
        puts "[#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}][#{type}] #{message.to_s}"
      end
    end
    class StaticConfig < Hash
      def initialize! config
        config.each { | key, value |
          self[key.intern] = value
        }
      end
    end
    #-- accessor
    @@s_rootpath = "#{File.dirname( File.expand_path( __FILE__ ) )}/"
    @@s_resource = {}
    @@s_logger = StaticLogger.new
    @@s_config = StaticConfig.new
    def __ROOT__ path=nil
      @@s_rootpath = path if path
      @@s_rootpath
    end
    def resource
      @@s_resource
    end
    def logger
      @@s_logger
    end
    def config
      @@s_config
    end
    def absolute path
      path.sub( './', __ROOT__ )
    end
  end
end
