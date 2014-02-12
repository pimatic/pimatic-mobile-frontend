

$(document).on "pagebeforecreate", ->
  if pimatic.inited then return

  pimatic.inited = yes

  pimatic.socket = io.connect("/", 
    'connect timeout': 20000
    'reconnection delay': 500
    'reconnection limit': 2000 # the max delay
    'max reconnection attempts': Infinity
  )

  pimatic.socket.on 'log', (entry) -> 
    if entry.level is 'error' 
      pimatic.errorCount++
    pimatic.showToast entry.msg
    #console.log entry

  pimatic.socket.on 'connect', ->
    pimatic.loading "socket", "hide"
    if window.applicationCache?
      try
        window.applicationCache.update()
      catch e
        console.log e

  pimatic.socket.on 'connecting', ->
    #console.log "connecting"
    pimatic.loading "socket", "show",
      text: __("connecting")
      blocking: (not pimatic.pages.index.hasData)

  ###
    unused socket events:
  ###

  # pimatic.socket.on 'connect_failed', ->
  #   console.log "connect_failed"

  # pimatic.socket.on 'reconnect_failed', ->
  #   console.log "reconnect_failed"

  # pimatic.socket.on 'reconnect', ->
  #   console.log "reconnect"

  # pimatic.socket.on 'reconnecting', ->
  #   console.log "reconnecting"

  pimatic.socket.on 'disconnect', ->
    #console.log "disconnect"
    pimatic.loading "socket", "show",
      text: __("connection lost, retrying")
      blocking: (not pimatic.pages.index.hasData)

  onConnectionError = (reason) ->
    if reason is 'handshake unauthorized'
      # trigger a reload of the data here to force getting the auth dialog
      return pimatic.pages.index.toLoginPage()
    if reason? then reason = ": #{reason}"
    else reason = ''
    pimatic.loading "socket", "show",
      text: __("could not connect%s, retrying", reason)
      blocking: (not pimatic.pages.index.hasData)
    setTimeout ->
      pimatic.socket.socket.connect()
    , 2000

  pimatic.socket.on 'error', onConnectionError
  pimatic.socket.on 'connect_error', onConnectionError

  pmData = $.localStorage.get('pmData')
  unless pmData? then pmData = {}
  pimatic.rememberMe = (if pmData?.rememberMe then yes else no)
  pmData.rememberMe = pimatic.rememberMe
  if pimatic.rememberMe
    pimatic.storage = $.localStorage 
  else
    pimatic.storage = $.sessionStorage 
    $.localStorage.removeAll()
  pimatic.storage.set('pmData', pmData)
