require 'matrix'
require 'assets/graph'

class PagesController < ApplicationController
  before_filter :current_user
  def index
    user = User.find(session[:user_id])
    @api = Koala::Facebook::API.new(user.oauth_token)
    logger.info user.oauth_token
    query = {
              "events"=>"SELECT eid, rsvp_status FROM event_member WHERE uid = me()",
              "details"=>"SELECT eid, name, description, creator, start_time, end_time FROM event WHERE eid IN (SELECT eid FROM  #events)",
              "creators"=>"SELECT uid, name FROM user WHERE uid IN (SELECT creator FROM #details)",
              "friends"=>"SELECT uid2 FROM friend WHERE uid1 = me()"
            }
    begin
      res = @api.fql_multiquery query
    rescue Koala::Facebook::AuthenticationError => e
      @error = 'Oops! An error occurred when connecting to Facebook. Try sign out and in again!'
      user.refresh_access_token
    rescue Exception => e
      logger.info e.message
      @error = 'Oops! An error occurred when connecting to Facebook. Try sign out and in again!'
    end
    if res
      @events = res['events']
      friends = res['friends']
      creators = res['creators']
      details = res['details']
      
      @events.each do |e|
        detail = details.select{|d| d['eid'] == e['eid']}.first
        e['name'] = detail['name']
        e['description'] = detail['description']
        e['creator'] = detail['creator']
        e['creator_name'] = creators.select{|c| c['uid'] == detail['creator']}.first['name']
        e['start_time'] = detail['start_time']
        e['end_time'] = detail['end_time']
        f_id = friends.collect{|f| f['uid2']}
        e['creator_friend'] = f_id.include? detail['creator']
      end
    end
  end

  def event
    user = User.find(session[:user_id])
    @api = Koala::Facebook::API.new(user.oauth_token)
    query = {
              "members"=>"select uid, name from user where uid in (select uid from event_member where eid = " + params[:id] + " and rsvp_status = 'attending')",
              "links"=>"select uid1, uid2 from friend where uid1 in (SELECT uid from #members) and uid2 in (SELECT uid from #members)"
            }
    begin
      res = @api.fql_multiquery query
    rescue Koala::Facebook::AuthenticationError => e
      @error = 'Oops! An error occurred when connecting to Facebook. Try sign out and in again!'
      user.refresh_access_token
    rescue Exception => e
      logger.info e.message
      @error = 'Oops! An error occurred when connecting to Facebook. Try sign out and in again!'
    end
    
    if res.nil?
      return false
    end
    @members = res['members']
    ids = @members.collect{|m| m['uid']}
    @hash = Hash[ids.map.with_index.to_a]
    links = res['links']
    @connections = []
    links.each do |l|
      @connections.push( {uid1:l['uid1'].to_i, uid2:l['uid2'].to_i} )
    end
    logger.info @connections
    graph = Graph.new
    ids.each do |m| 
      graph.push m 
    end
    @connections.each do |c|
      graph.connect_mutually( c[:uid1], c[:uid2], 1 )
    end
    @pos = forcedirected(graph, 0.1, 50000, 800, 1000)
    
    
    render layout: "none"
  end
  
  def forcedirected(g, k1, k2, len, size)
    pos = {}
    force = {}
    rand = Random.new
    g.each do |vertex|
      pos[vertex] = { x: rand.rand(size)-size/2, y: rand.rand(size)-size/2, z: rand.rand(size)-size/2}
      force[vertex] = { x: 0, y: 0, z: 0}
    end
    500.times do |x|
      g.each do |vertex|
        force[vertex] = { x: 0, y: 0, z: 0}
        g.neighbors(vertex).each do |neighbor|
          distx = (pos[neighbor][:x] - pos[vertex][:x])
          disty = (pos[neighbor][:y] - pos[vertex][:y])
          distz = (pos[neighbor][:z] - pos[vertex][:z])
          dist = Math.sqrt(distx*distx + disty*disty + distz*distz)
          force[vertex][:x] += k1 * (dist - len) * distx / dist;   
          force[vertex][:y] += k1 * (dist - len) * disty / dist;
          force[vertex][:z] += k1 * (dist - len) * distz / dist;
        end
        g.each do |other|
          if vertex != other
            distx = (pos[other][:x] - pos[vertex][:x])
            disty = (pos[other][:y] - pos[vertex][:y])
            distz = (pos[other][:z] - pos[vertex][:z])
            dist = Math.sqrt(distx*distx + disty*disty + distz*distz)
            force[vertex][:x] -= k2 * distx / (dist * dist * dist)
            force[vertex][:y] -= k2 * disty / (dist * dist * dist)
            force[vertex][:z] -= k2 * distz / (dist * dist * dist)
          end
        end
      end
      g.each do |vertex|
        pos[vertex][:x] += force[vertex][:x]
        pos[vertex][:x] = 600 if pos[vertex][:x] > 600
        pos[vertex][:y] += force[vertex][:y]
        pos[vertex][:y] = 600 if pos[vertex][:y] > 600
        pos[vertex][:z] += force[vertex][:z]
        pos[vertex][:z] = 600 if pos[vertex][:z] > 600
      end
    end
    return pos
  end
  
end
