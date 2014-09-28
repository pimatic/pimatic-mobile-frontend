
tc = pimatic.tryCatch

$(document).ready( tc (event) ->

  class LogiViewModel
    showLoginDialog: ->
      pimatic.socket.io.disconnect()
      jQuery.mobile.changePage '#login-page', transition: 'flip'
    hideLoginDialog: ->
      jQuery.mobile.changePage '#index', transition: 'flip'

  pimatic.pages.login = loginPage = new LogiViewModel()

)

$(document).on("pagebeforeshow", '#login-page', (event) ->
  if pimatic.socket.io?.connected
    pimatic.pages.login.hideLoginDialog()
    return false
  return true
)

$(document).on("submit", '#login-page #loginForm', tc (event) -> 
  rememberMe = $("#loginForm #rememberMe").val()
  pimatic.loading("socket", "show", {
    text: __("Logging in")
    blocking: yes
  })
  $.ajax({
    type: "POST"
    url: '/login'
    data: $("#loginForm").serialize()
    global: false
  }).done( (result)->
    pimatic.loading("socket", "show", {
      text: __("Connecting")
      blocking: yes
    })
    setTimeout( ( ->
      pimatic.rememberme(result.rememberMe)
      pimatic.socket.io.disconnect()
      pimatic.socket.io.reconnect()
    ), 1)
  )
  .fail( => pimatic.loading("socket", "hide"))
  .fail(ajaxAlertFail)
  event.preventDefault()
  return false
)