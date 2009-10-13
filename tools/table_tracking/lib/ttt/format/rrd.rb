require 'rubygems'
require 'activerecord'
require 'ttt/db'
require 'ttt/table'

module TTT
  class RRDFormatter < Formatter
    runner_for :rrd
    def format(rows, *args)
      options=args.extract_options!
      path=need_option("path")
      updint=need_option("update_interval")
      if updint =~ /(\d+(?:\.?\d+)?)([mhd])?/
        updint=case $2
                 when 'm'
                   $1.to_f.minutes
                 when 'h'
                   $1.to_f.hours
                 when 'd'
                   $1.to_f.days
               end
      elsif updint.to_f == 0.0
        raise ArgumentError, "option update_interval must resolve to a number greater than 0."
      end
      updint=updint.to_i
      reject_ignores(TTT::TrackingTable.tables[:volume].find_most_recent_versions).each do |r|
        rra_path="#{path}/#{r.server}_#{r.database_name}_#{r.table_name}.rrd"
        next if r.unreachable?
        if File.exist? rra_path
          lastupd=%x{rrdtool last #{rra_path}}.chomp
          lastupd=Time.at lastupd.to_i
          TTT::TrackingTable.tables[:volume].find(:all, :conditions => ['run_time > ? AND server = ? AND database_name = ? AND table_name = ?', lastupd, r.server, r.database_name, r.table_name ]).each do |nr|
            cmd="rrdtool update #{rra_path} #{nr.run_time.to_i}:#{nr.data_length}:#{nr.index_length}:#{nr.data_free}"
            puts cmd
            %x{#{cmd}}
          end
        else
          first=TTT::TrackingTable.tables[:volume].find(:first, :conditions => ['server = ? AND database_name = ? AND table_name = ?', r.server, r.database_name, r.table_name ])
          cmd=["rrdtool create #{rra_path}",
              "--step #{updint}", "--start #{first.run_time.to_i-10}",
              "DS:data_length:GAUGE:#{updint*2}:U:U",
              "DS:index_length:GAUGE:#{updint*2}:U:U",
              "DS:data_free:GAUGE:#{updint*2}:U:U",
              "RRA:LAST:0.50:1:1000",
              "RRA:AVERAGE:0.50:2:2000",
              "RRA:AVERAGE:0.50:4:4000"
              ].join(' ')
          puts cmd
          %x{#{cmd}}
          TTT::TrackingTable.tables[:volume].find(:all,
                           :conditions => ['server = ? AND database_name = ? AND table_name = ?',
                             r.server, r.database_name, r.table_name ]).each do |nr|
            cmd="rrdtool update #{rra_path} #{nr.run_time.to_i}:#{nr.data_length}:#{nr.index_length}:#{nr.data_free}"
            puts cmd
            %x{#{cmd}}
                             end
        end
      end
      true
    end
  end
end
