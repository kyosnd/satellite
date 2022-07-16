# -*- coding: utf-8 -*-

#-- default requires.
require 'find'
require 'yaml'
require 'time'
require 'logger'
require 'active_record'
require 'active_support'

module Satellite

  #-- module variables.
  @@status = false
  @@laptime = Time.at 0
  @@signal_call = nil

  # 
  # param:keys
  #  :config => String of config file path.
  #  :signal => Proc object for signal : `kill -INT ****`
  #  :initalize => Proc object for set-up(only initialize).
  #  :make_stopper => Bool is stopper made or not.
  def Satellite.initialize!( param={} )
    # set-up.
    param = {} unless Hash === param
    __ROOT__ "#{File.dirname( File.expand_path( param[:root] ) )}/" if param[:root]
    @@signal_call = param[:signal] if param[:signal] && Proc === param[:signal]
    # load config.
    config.initialize! YAML::load_file( param[:config] ? param[:config] : "#{__ROOT__}config.yml" )
    # check config-keys.
    [:interval, :log, :requires, :database].each { | key |
      return logger.error( 'config has not key: ' + key.to_s ) unless config[key]
    }
    logger.initialize!( config[:log] )
    logger.system( "#--------<  Satellite * ver.#{SatelliteVersion}  >--------#" )

    #-- config and signal-trap initialize.
    logger.system( 'start set-up.' )
    Signal.trap(:SIGTERM) {
      logger.system( 'call SIGTERM.' )
      @@status = false
    }
    Signal.trap(:INT) {
      logger.system( 'call INT.' )
      @@signal_call.() if @@signal_call
    }
    #-- setup active record.
    logger.system( 'ActiveRecord connect database.' )
    ActiveRecord::Base.establish_connection( config[:database] )
    #-- additional requires.
    logger.system( 'require ruby files.' )
    Find.find( File.expand_path( absolute( config[:requires] ) ) ) { | path |
      if /\.rb$/ =~ path
        logger.error( 'Invalid ruby file : ' + path ) unless require path 
      end
    } if FileTest.directory? absolute( config[:requires] )
    #-- begin daemon.
    unless DebugMode
      logger.system( '<- daemon running' )
      Process.daemon( true )
      if param[:make_stopper]
        filepath = "#{__ROOT__}stop_satellite.sh"
        File.open(filepath, 'w') { |file|
          file.write( "#!/bin/sh\necho #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}\ndate '+%Y-%m-%d %T'\nkill #{Process.pid}\n" + 
                      "echo stopping now...\nwhile true; do\nif [ -d /proc/#{Process.pid} ]; then sleep 1; else break; fi\ndone\nrm -f #{filepath}" )
        }
        `chmod 755 #{filepath}`
      end
      if param[:make_viewer]
        filepath = "#{__ROOT__}view_satellite.sh"
        File.open(filepath, 'w') { |file|
          file.write( "#!/bin/sh\ntail -fn 300 #{absolute(config[:log]['path'])}\nrm -f #{filepath}" )
        }
        `chmod 755 #{filepath}`
      end
    else
      logger.system( '<- debugger running' )
    end
    #-- initialize
    param[:initalize].() if param[:initalize] && Proc === param[:initalize]
    @@status = true
  end

  # 
  def Satellite.run
    #-- ready check.
    if Satellite.continue?
      #-- main process.
      logger.system( 'start.' )
      while Satellite.continue?
        if config[:interval] < Time.now - @@laptime
          begin
            yield
          rescue Exception => exc
            logger.exception( exc )
          end
          @@laptime = Time.now
        end
        sleep 1
      end
      ActiveRecord::Base.connection.close
      logger.system( 'stopped.' )
    end
  end

  # 
  def Satellite.websocket
    #-- ready check.
    if Satellite.continue?
      #-- main process.
      logger.system( 'start.' )
      require 'em-websocket'
      thread = Thread.new {
        ActiveRecord::Base.connection_pool.with_connection {
          EventMachine.run {
            EventMachine::WebSocket.start({
#              :secure => true,
#              :tls_options => {
#                :private_key_file => "/private/key",
#                :cert_chain_file => "/ssl/certificate"
#              }
              :host => config[:websocket]['host'],
              :port => config[:websocket]['port'].to_i
            }) { | socket |
              begin
                yield socket
              rescue Exception => exc
                logger.exception( exc )
              end
            }
          }
        }
      }
      while thread.alive?
        thead.kill unless Satellite.continue?
        sleep 1
      end
      ActiveRecord::Base.connection.close
      logger.system( 'stopped.' )
    end
  end

  # 
  def Satellite.continue?
    @@status
  end
end
