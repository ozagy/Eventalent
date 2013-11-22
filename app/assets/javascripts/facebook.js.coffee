jQuery ->
  $('body').prepend('<div id="fb-root"></div>')

  $.ajax
    url: "#{window.location.protocol}//connect.facebook.net/en_US/all.js"
    dataType: 'script'
    cache: true


window.fbAsyncInit = ->
  FB.init(appId: '682158981819004', cookie: true)

  $('#sign-in, #sign-in-large').click (e) ->
    e.preventDefault()
    FB.login (response) ->
      window.location = '/auth/facebook/callback' if response.authResponse

  $('#sign-out').click (e) ->
    FB.getLoginStatus (response) ->
      if response.authResponse
        FB.logout (response) ->
          window.location.reload();
  true
