# General
# -------

pimatic.loading = (what, options) ->
  setTimeout ->
    $.mobile.loading(what, options)
  , 1

$.ajaxSetup timeout: 20000 #ms

$(document).ajaxStart ->
  pimatic.loading "show",
    text: "Loading..."
    textVisible: true
    textonly: false

$(document).ajaxStop ->
  pimatic.loading "hide"

$(document).ajaxError -> #nop

$(document).ready => 
  if window.applicationCache 
    window.applicationCache.addEventListener 'updateready', (e) =>
      if window.applicationCache.status is window.applicationCache.UPDATEREADY 
        window.applicationCache.swapCache()
        if confirm('A new version of this site is available. Load it?')
          window.location.reload();
    , false
, false

ajaxShowToast = (data, textStatus, jqXHR) -> 
  pimatic.showToast (if data.message? then data.message else 'done')

ajaxAlertFail = (jqXHR, textStatus, errorThrown) ->
  data = null
  try
    data = $.parseJSON jqXHR.responseText
  catch e 
    #ignore error
  message =
    if data?.error?
      data.error
    else if errorThrown? and errorThrown != ""
      message = errorThrown
    else if textStatus is 'error'
      message = 'no connection'
    else
      message = textStatus

  alert __(message)
  return true

pimatic.showToast = 
  if device? and device.showToast?
    device.showToast
  else
    (msg) -> $('#toast').text(msg).toast().toast('show')

__ = (text, args...) -> 
  translated = text
  if locale[text]? then translated = locale[text]
  else console.log 'no translation yet:', text
    
  for a in args
    translated = translated.replace /%s/, a
  return translated

( ->

  lastTickTime = new Date().getTime()
  tick = ->
    now = new Date().getTime()
    if now - lastTickTime > 5000
      # the tick should be triggerd every 2000 seconds, so the device must be in standby
      # so do a refresh
      pimatic.pages.index.loadData()
    lastTickTime = now
    setTimeout tick, 2000
  tick()
)()

unless window.console? then window.console = { log: -> }
