# General
# -------

$.ajaxSetup timeout: 20000 #ms

( ->
  loadingStack = 0
  loadingAjax = no
  proxied = $.mobile.loading
  $.mobile.loading = (action, options, source) ->
    if action is 'show'
      loadingStack++
      proxied.call this, action, options
      if source is 'ajax'
        loadingAjax = yes
    else 
      source = options
      if source is 'ajax'
        loadingAjax = no
      if loadingStack > 0
        loadingStack--
      if loadingStack is 0 and loadingAjax is no
        proxied.call this, 'hide'
  return
)()


$(document).ajaxStart ->
  $.mobile.loading("show",
    text: "Loading..."
    textVisible: true
    textonly: false
  , 'ajax')

$(document).ajaxStop ->
  $.mobile.loading "hide", 'ajax'

$(document).ajaxError -> #nop


ajaxShowToast = (data, textStatus, jqXHR) -> 
  showToast (if data.message? then message else 'done')

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
