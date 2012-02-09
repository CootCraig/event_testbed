# http://pragprog.com/magazines/2010-12/new-series-everyday-jruby
# http://zerioh.tripod.com/ressources/sockets.html

# Network socket event source
# Imagine the events are for a door sensor
#
# States are [open] [closed] [missing]
# events are <open> <close> <remove> <replace>
#
# Transitions are
#  [closed] <open> [open]
#  [open] <close> [closed]
#  [open] <remove> [missing]
#  [missing] <replace> [open]
#
#  Server will accept connections
#  Each connection is assigned a unique door name 1001 1002 1003 ...
#  When a connect is rececived send a message { :door => "1001", :state => "open | closed | missing", :time => time }
#  Then at random times send message { :door => "1001", :start_state => state, :event => event, :end_state => state, :time => time }

require "rubygems"
require "bundler/setup"

require "json"
require "celluloid/io"
require 'socket'
require 'ruby-debug'

client = false
ARGV.each do |arg|
  client = true if arg.downcase.include?('client')
end

class ClientAcceptActor
  include Celluloid::IO

  @@server_port = 4001
  @@doors = {} # 'door_name' -> DoorEventActor

  def initialize
    debugger
    @server = TCPServer.new(@@server_port)
    puts "Accepting door clients on port #{@@server_port} server.class #{@server.class}"
    run!
  end
  def run
    loop do
      client_socket = @server.accept

      door_number = 1001
      unused_door_found = false
      until unused_door_found
        if @@doors[door_number.to_s]
          door_number += 1
        else
          puts "New client connected to Door #{door_number}"
          @@doors[door_number.to_s] = DoorEventActor.new(door_number.to_s,client_socket)
          unused_door_found = true
        end
      end
    end
  end
  def self.server_port
    @@server_port
  end
  def self.doors
    @@doors
  end
end
class DoorEventActor
  include Celluloid::IO
  def initialize(door_name,socket)
    @door_name = door_name
    @socket = socket
    _, @client_port, @host = socket.peeraddr
    @state = DoorEventActor.pick_initial_state
    @event_timer = nil
    run!
  end
  def run
    start_msg = { door: @door_name, state: @state, time: Time.now.to_s }
    puts "start_msg #{start_msg} socket.class #{@socket.class}"
    @socket.puts(JSON( start_msg ))
    @event_timer = after(sleep_time()) { event! }
    handle_client_close!
  end
  def event
    event,new_state = next_transition()
    event_msg = { door: @door_name, start_state: @state, event: event, end_state: new_state, time: Time.now.to_s }
    puts "event_msg #{event_msg}"
    @socket.puts( JSON( event_msg ) )
    @state = new_state
    @event_timer = after(sleep_time()) {event!}
  end
  def handle_client_close
    begin
      puts "handle_client_close door #{@door_name}"
      @socket.readpartial(4096)
      puts "handle_client_close after readpartial door #{@door_name}"
      handle_client_close!
    rescue
      puts "Client terminated. door #{@door_name} host #{@host} port #{@client_port}"
      ClientAcceptActor.doors.delete(@door_name)
      terminate
    end
  end
  def self.pick_initial_state
    a_rand = rand
    if a_rand < 0.2 then 'open'
    elsif a_rand < 0.91 then 'closed'
    else 'missing'
    end
  end
  def sleep_time
    5 + rand(10)
  end
  def next_transition
    case @state
    when 'closed' then [ '<open>', 'open' ]
    when 'missing' then [ '<replace>', 'open' ]
    else # open
      if rand() < 0.1
        [ '<remove>', 'missing' ]
      else
        [ '<close>', 'closed' ]
      end
    end
  end
end

if client
  socket = TCPSocket.open('localhost',ClientAcceptActor.server_port)
  begin
    while line = socket.gets
      if line.length > 1
        if line =~ /{.*:.*}/
          data = JSON.parse(line)
          puts "data #{data}"
        end
      end
    end
  rescue IOError => e
    puts "Server closed"
  end
else
  server_actor = ClientAcceptActor.new
  loop do
    sleep
  end
end

