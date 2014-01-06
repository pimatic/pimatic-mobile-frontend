  
socket = io.connect("/", 
  'connect timeout': 20000
  'reconnection delay': 500
  'reconnection limit': 2000 # the max delay
  'max reconnection attempts': Infinity
)

socket.on 'log', (entry) -> 
  if entry.level is 'error' 
    errorCount++
    updateErrorCount()
  showToast entry.msg
  console.log entry

socket.on 'reconnect', ->
  $.mobile.loading "hide"
  loadData()

socket.on 'disconnect', ->
 $.mobile.loading "show",
  text: __("connection lost, retying")+'...'
  textVisible: true
  textonly: false

onConnectionError = ->
  $.mobile.loading "show",
    text: __("could not connect, retying")+'...'
    textVisible: true
    textonly: false
  setTimeout ->
    socket.socket.connect(->
      $.mobile.loading "hide"
      loadData()
    )
  , 2000

socket.on 'error', onConnectionError
socket.on 'connect_error', onConnectionError