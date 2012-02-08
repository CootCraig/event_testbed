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

require 'java'

import java.io.BufferedReader
import java.io.InputStreamReader
import java.lang.Double
import java.net.ServerSocket

