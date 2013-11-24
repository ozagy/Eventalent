(function() {
  $(function() {
    $('body').prepend('<div id="fb-root"></div>');
    return $.ajax({
      url: "" + window.location.protocol + "//connect.facebook.net/en_US/all.js",
      dataType: 'script',
      cache: true
    });
  });

  window.fbAsyncInit = function() {
    FB.init({
      appId: '682158981819004',
      cookie: true
    });
    FB.getLoginStatus(function(response) {
      console.log(response);
      if (response.status!='connected' && 
      	document.title != 'Eventalent - Welcome'){	
	    window.location = '/';
	  }
    });
    $('#sign-in, #sign-in-large').click(function(e) {
      e.preventDefault();
      FB.login(function(response) {
        if (response.authResponse) {
          console.log(response);
          window.location = '/auth/facebook/callback';
        }
      },{scope: 'user_friends,user_events,friends_events'});
    });
    $('#sign-out').click(function(e) {
      window.location = '/signout';
    });
    refresh_fb();
    return true;
  };

}).call(this);