
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
  $.ajax({
    type: "POST"
    url: '/login'
    data: $("#loginForm").serialize()
  }).done( ->
    pimatic.loading("socket", "show", {
      text: __("Connecting")
      blocking: no
    })
    setTimeout( ( ->
      pimatic.socket.io.disconnect()
      pimatic.socket.io.reconnect()
    ), 1)
  ).fail(ajaxAlertFail)
  event.preventDefault()
  return false
)