class User < ActiveRecord::Base
  def self.from_omniauth(auth)
    where(auth.slice(:provider, :uid)).first_or_initialize.tap do |user|
      user.provider = auth.provider
      user.uid = auth.uid
      user.name = auth.info.name
      user.oauth_token = auth.credentials.token
      user.oauth_expires_at = Time.at(auth.credentials.expires_at)
      user.save!
    end
  end
  
  def refresh_access_token
    logger.info 'refresh'
    begin
      fb = YAML.load_file('config/facebook.yml')
      @oauth = Koala::Facebook::OAuth.new(fb['app_id'], fb['app_secret'])
      info = @oauth.exchange_access_token_info(self.oauth_token)
      if info['access_token']
        self.oauth_token = info['access_token']
        self.oauth_expires_at = Time.at(Time.now + info['expires'].to_i)
        self.save!
      end
      redirect_to '/'
    rescue Exception => e  
      logger.info 'info:'+e.message
    end
  end
  
  def token_expired?
    if ( self.oauth_expires_at - Time.now ) > 0
      return false
    else
      return true
    end
  end
  
end