# http://pragprog.com/magazines/2010-12/new-series-everyday-jruby
# http://zerioh.tripod.com/ressources/sockets.html

# Network socket event source
# Imagine the events are for a door sensor
#
# States are [open] [closed] [missing]
# events are >open> >close> >remove> >replace>
#
# Transitions are
#  [closed] >open> [open]
#  [open] >close> [closed]
#  [open] >remove> [missing]
#  [missing] >replace> [open]
#
#  Server will accept connections
#  Each connection is assigned a unique door name 1001 1002 1003 ...
#  When a connect is rececived send a message { :door => "1001", :state => "open | closed | missing", :time => time }
#  Then at random times send message { :door => "1001", :start_state => state, :event => event, :end_state => state, :time => time }

require "rubygems"
require "bundler/setup"

# require your gems as usual
require "json"
require "celluloid"
require 'socket'

class DoorEventActor
  include Celluloid
  def initialize(door_name,socket)
    @door_name = door_name
    @socket = socket
    @state = DoorEventActor.pick_initial_state
  end
  def run
    start_msg = { door: @door_name, state: @state, time: Time.now.to_s }
    puts "start_msg #{start_msg}"
    @socket.puts(JSON( start_msg ))
    while true do
      sleep(sleep_time())
      event,new_state = next_transition()
      event_msg = { door: @door_name, start_state: @state, event: event, end_state: new_state, time: Time.now.to_s }
      puts "event_msg #{event_msg}"
      @socket.puts( JSON( event_msg ) )
      @state = new_state
    end
  end
  def self.pick_initial_state
    a_rand = rand
    if a_rand < 0.2 then 'open'
    elseif a_rand < 0.91 then 'closed'
    else 'missing'
    end
  end
  def sleep_time
    10 + rand(2 * 60)
  end
  def next_transition
    case @state
    when 'closed' then [ 'open', 'open' ]
    when 'missing' then [ 'replace', 'open' ]
    else # open
      if rand() < 0.1
        [ 'remove', 'missing' ]
      else
        [ 'close', 'closed' ]
      end
    end
  end
end

doors = {} # 'door_name' -> DoorEventActor

port = 4001
server = TCPServer.open(port)
puts "Starting Door Server on port #{port}"
while true do
  client_socket = server.accept

  door_number = 1001
  unused_door_found = false
  begin
    if doors[door_number.to_s]
      door_number += 1
    else
      puts "New client connected to Door #{door_number}"
      doors[door_number.to_s] = DoorEventActor.new(door_number.to_s,client_socket)
      doors[door_number.to_s].run!
      unused_door_fount = true
    end
  end until unused_door_found
end

