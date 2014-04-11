# General
# -------

# scope this function
( ->

  pendingLoadings = {}

  # build a string containing all loading messages
  buildLoadingMessage = ->
    mobileLoadingOptions = {
      text: ''
      textVisible: true
      textonly: false
    }
    blocking = no
    for k, options of pendingLoadings
      if options.text?
        if mobileLoadingOptions.text.length isnt 0
          mobileLoadingOptions.text += ', '
        mobileLoadingOptions.text += options.text
      if options.blocking is yes
        blocking = yes
    if mobileLoadingOptions.text.length isnt 0
      mobileLoadingOptions.text += '...'
    else
      mobileLoadingOptions.textVisible = no
    if blocking
      $('body').addClass('ui-loading-blocking')
    else 
      $('body').removeClass('ui-loading-blocking')
      mobileLoadingOptions.textVisible = yes
      mobileLoadingOptions.textonly = yes
      if mobileLoadingOptions.text.length is 0
        mobileLoadingOptions.text = __('Loading') + '...'

    return mobileLoadingOptions


  pimatic.loading = (context, action, options) ->
    ###
    There is aproblem showing the loading indicater in pageinit. It doesn't get showen if 
    $.mobile.loading is called directly. Wrapping the call in setTimeut seems to fix the issue
    ###
    setTimeout( ->
      switch action
        when 'show'
          # add the message to the pending loadings
          pendingLoadings[context] = options
          # build a string containing all loading messages
          # and show the loading indicator
          $.mobile.loading('show', buildLoadingMessage())
        when 'hide'
          # delete the context
          delete pendingLoadings[context]
          # hide the loading indicator if we have nothing to load anymore
          if (k for k of pendingLoadings).length is 0
            $.mobile.loading('hide')
            $('body').removeClass('ui-loading-blocking')
          else
            #update the message
            $.mobile.loading('show', buildLoadingMessage())
    , 1)
    return

  pimatic.loading.pendingLoadings = pendingLoadings

  ###
  jQuery mobile hides the loading indicater at page change. So we reshow it if we have pending 
  requests
  ###
  $(document).on "pagechange", (event) ->  
    setTimeout( ->
      if (k for k of pendingLoadings).length isnt 0
        mobileLoadingOptions = buildLoadingMessage()
        $.mobile.loading('show', mobileLoadingOptions)
    , 1)
    return

  $(document).on "vclick", ".ui-loader", =>
    pimatic.pages.index.toLoginPage()


  # Disable jquerys scroll to top on transitions when we scroll inside the page divs
  unless overthrow.support is 'none'
    $.mobile.Transition.prototype.scrollPage =  => #nop

)()

$.ajaxSetup timeout: 20000 #ms

$(document).ajaxStart ->
  pimatic.loading "ajax", "show",
    text: "loading"
    blocking: yes

$(document).ajaxStop ->
  pimatic.loading "ajax", "hide"

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

pimatic.try = (call) => 
  try
    call()
  catch e
    console.log "ignoring error: ", e 

window.ajaxShowToast = (data, textStatus, jqXHR) -> 
  pimatic.showToast (if data.message? then data.message else 'done')

window.ajaxAlertFail = (jqXHR, textStatus, errorThrown) ->
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
      message = __('No connection')
    else
      message = textStatus

  # Give other events time to process
  setTimeout( ->
    alert __(message)
  , 1)
  return true

$(document).ready => 

  pimatic.showToast = (
    if device? and device.showToast?
      device.showToast
    else
      $('#toast').toast()
      (msg) -> $('#toast').text(msg).toast('show')
  )

window.__ = (text, args...) -> 
  translated = text
  if locale[text]? then translated = locale[text]
  else console.log 'no translation yet:', text
    
  for a in args
    translated = translated.replace /%s/, a
  return translated

unless window.console? then window.console = { log: -> }
