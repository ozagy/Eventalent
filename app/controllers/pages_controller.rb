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
    rescue
      redirect_to signout_path
    end
    
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

  def event
  end
  
  
  def fql_query query 
    fql = @api.fql_query(query)
  end
  
  def fql_multiquery query

    fql = api.fql_multiquery(query)
    return
  end
  
end
