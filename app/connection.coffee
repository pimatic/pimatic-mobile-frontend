  
$(document).on "pagecreate", '#index', (event) ->
  pimatic.socket = io.connect("/", 
    'connect timeout': 20000
    'reconnection delay': 500
    'reconnection limit': 2000 # the max delay
    'max reconnection attempts': Infinity
  )

  pimatic.socket.on 'log', (entry) -> 
    if entry.level is 'error' 
      pimatic.errorCount++
      pimatic.pages.index.updateErrorCount()
    pimatic.showToast entry.msg
    console.log entry

  pimatic.socket.on 'connect', ->
    pimatic.loading "hide"
    pimatic.pages.index.loadData()
    if window.applicationCache?
      try
        window.applicationCache.update()
      catch e
        console.log e

  pimatic.socket.on 'disconnect', ->
   pimatic.loading "show",
    text: __("connection lost, retying")+'...'
    textVisible: true
    textonly: false

  onConnectionError = ->
    pimatic.loading "show",
      text: __("could not connect, retying")+'...'
      textVisible: true
      textonly: false
    setTimeout ->
      pimatic.socket.socket.connect()
    , 2000

  pimatic.socket.on 'error', onConnectionError
  pimatic.socket.on 'connect_error', onConnectionError