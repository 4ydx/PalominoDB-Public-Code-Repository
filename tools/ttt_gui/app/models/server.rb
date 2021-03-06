require 'ttt'
require 'ttt/collector'
require 'ttt/server'
class ServerNotFound < ActiveRecord::RecordNotFound ; end
class Server 
  attr_reader :stats
  attr_reader :name
  def self.find(name)
    srv=TTT::Server.find_by_name(name)
    if srv.nil?
      raise ServerNotFound, "No such server: #{name}"
    end
    stats={}
    TTT::TrackingTable.tables.each do |s,k|
      stats[s]=k.find_most_recent_versions({:conditions => ['server = ?', srv.name]}, :latest)
    end
    self.new(name, stats)
  end
  def self.all
    TTT::Server.all.map { |s| s.name }
  end

  def reload
    stats={}
    TTT::TrackingTable.tables.each do |s,k|
      stats[s]=k.find_most_recent_versions({:conditions => ['server = ?', name]}, :latest)
    end
  end

  def self.get_size(server)
    TTT::Server.find_by_name(server).cached_size
  end

  def get_size
    TTT::Server.find_by_name(name).cached_size
    #size=nil
    #@stats[:volume].each do |v|
    #  unless v.size.nil?
    #    size=0 if size.nil?
    #    size+=v.size
    #  end
    #end
    #size
  end

  def top_by_volume(n=5)
    TTT::Server.all(:order => :cached_size, :limit => n)
  end

  def self.each
    self.all.each { |s| yield(self.find(s)) }
  end

  def databases
    schms=TTT::Server.find_by_name(name).schemas.all(:order => 'cached_size DESC')
    schms.collect { |d| Database.find(d.server.name, d.name) }
  end

  def database(dname)
    Database.find(name, dname)
  end

  private

  def initialize(name,stats)
    @name=name
    @stats=stats
  end


end
