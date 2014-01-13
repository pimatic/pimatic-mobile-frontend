# General
# -------

$.ajaxSetup timeout: 20000 #ms


loading = (what, options) ->
  setTimeout ->
    $.mobile.loading(what, options)
  , 1

$(document).ajaxStart ->
  loading "show",
    text: "Loading..."
    textVisible: true
    textonly: false

$(document).ajaxStop ->
  loading "hide"

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
  showToast (if data.message? then data.message else 'done')

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

voiceCallback = (matches) ->
  $.get "/api/speak",
    word: matches
  , (data) ->
    showToast data
    $("#talk").blur()

showToast = 
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

unless window.console? then window.console = { log: -> }
