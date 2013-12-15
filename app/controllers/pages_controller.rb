require 'matrix'
require 'assets/graph'

class PagesController < ApplicationController
  before_filter :current_user
  def index
    user = User.find(session[:user_id])
    @api = Koala::Facebook::API.new(user.oauth_token)
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
        e['start_time'] = Time.parse(detail['start_time']).strftime "%Y-%m-%d %H:%M:%S %Z"
        e['end_time'] = Time.parse(detail['end_time']).strftime "%Y-%m-%d %H:%M:%S %Z" if detail['end_time']
        f_id = friends.collect{|f| f['uid2']}
        e['creator_friend'] = f_id.include? detail['creator']
      end
    end
  end
  
  def help
  
  end

  def event
    user = User.find(session[:user_id])
    @api = Koala::Facebook::API.new(user.oauth_token)
    query = {
              "members"=>"select uid, name, sex, username from user where uid in (select uid from event_member where eid = " + params[:id] + " and rsvp_status = 'attending')",
              "thumbnails"=>"SELECT id, url FROM square_profile_pic WHERE id in (SELECT uid from #members) AND size = 50",
              "links"=>"select uid1, uid2 from friend where uid1 in (SELECT uid from #members) and uid2 in (SELECT uid from #members)",
              "event"=>"select name, description, creator, start_time, end_time, location from event where eid = "+ params[:id],
              "creator"=>"SELECT uid, name FROM user WHERE uid IN (SELECT creator FROM #event)",
              "friends"=>"SELECT uid2 FROM friend WHERE uid1 = me()",
              "me" => "SELECT uid, name, sex, username from user where uid = "+ @current_user.uid, 
              "links_me" => "select uid1, uid2 from friend where uid1 = "+ @current_user.uid + " and uid2 in (SELECT uid from #members)",
              "thumbnail_me"=>"SELECT id, url FROM square_profile_pic WHERE id = "+ @current_user.uid + " AND size = 50"
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
      @members = res['members']
      thumbnails = res['thumbnails']
      @event = res['event'][0]
      @creator = res['creator'][0]
      friends = res['friends']
      @friends = friends.collect{|f| f['uid2'].to_i }
      ids = @members.collect{|m| m['uid']}
      links = res['links']
      if ids.exclude? res['me'][0]['uid']
        @members.push res['me'][0]
        ids.push res['me'][0]['uid']
        links = [links, res['links_me']].flatten
        thumbnails.push res['thumbnail_me'][0]
      end
      @hash = Hash[ids.map.with_index.to_a]
      @connections = []
      links.each do |l|
        @connections.push( {uid1:l['uid1'].to_i, uid2:l['uid2'].to_i} )
      end
      graph = Graph.new
      ids.each do |m| 
        graph.push m 
      end
      @thumbnails = {}
      thumbnails.each do |t|
        @thumbnails[t['id']] = t['url']
      end
      @connections.each do |c|
        graph.connect_mutually( c[:uid1], c[:uid2], 1 )
      end
      @pos = forcedirected(graph, 0.1, 80000, 500, 1000)
      @eig = eigenvector(graph, @connections)
      @deg = degree(graph)
      @dis = graph.dijkstra(res['me'][0]['uid'])
    end
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
    800.times do |x|
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
  
  def degree(g)
    deg = {}
    g.each do |vertex|
      deg[vertex] = g.neighbors(vertex).count
    end
    return deg
  end
  
  def eigenvector(g, connections)
    hash = Hash[g.map {|v| [v,g.index(v)]}]
    adj_arr = Array.new(g.size){ Array.new(g.size){ 0 } }
    connections.each do |c|
      adj_arr[hash[c[:uid1]]][hash[c[:uid2]]] = 1
      adj_arr[hash[c[:uid2]]][hash[c[:uid1]]] = 1
    end
    adj = Matrix.rows(adj_arr)
    v, d, vi = adj.eigensystem
    eig_v = v.column(g.size - 1)
    eig = {}
    g.each do |vertex|
      eig[vertex] = eig_v.[](g.index(vertex)).round(2)
    end
    return eig
  end
end
