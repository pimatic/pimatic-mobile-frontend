# General
# -------

# scope this function
( ->

  Highcharts.setOptions(
    global:
      useUTC: false
  )

  $.datepicker.setDefaults({
    dateFormat: 'yy-mm-dd'
  })

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
    window.location.reload()


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
          window.location.reload()
    , false
, false

pimatic.try = (func) -> 
  try
    return func.apply(this, arguments)
  catch e
    console.log "ignoring error: ", e 

pimatic.tryCatch = (func) ->
  return -> 
    try
      return func.apply(this, arguments)
    catch e
      TraceKit.report(e)

window.ajaxShowToast = (data, textStatus, jqXHR) -> 
  pimatic.showToast (if data.message? then data.message else 'done')

window.ajaxAlertFail = (jqXHR, textStatus, errorThrown) ->
  data = null
  try
    data = $.parseJSON jqXHR.responseText
  catch e 
    #ignore error
  message =
    if data?.message?
      data.message
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



$(document).ready( => 
  toastMessages = ko.observableArray([])
  ko.applyBindings({toastMessages}, $('#toasts')[0])
  #$('#toasts').toast()
  pimatic.showToast = (msg) -> 
    message = {
      message: msg
    }
    toastMessages.push(message)
    setTimeout( =>
      toastMessages.remove(message)
    4500)
    #$('#toasts').toast('show')
    return
  return
)

pimatic.isValidId = (id) => id.match(/^[a-z0-9_-]+$/)?
pimatic.isValidVariableName = (id) => id.match(/^[a-zA-Z0-9_-]+$/)?
pimatic.invalidIdMessage = (
  "The entered ID is not valid. Please use only lowercase alphanumeric characters" +
  ", \"_\" and \"-\"."
)
pimatic.invalidVariableNameMessage = (
  "The entered variable name is not valid. Please use only alphanumeric characters" +
  ", \"_\" and \"-\"."
)

pimatic.makeIdFromName = (str) =>
  str = str.replace(/^\s+|\s+$/g, "") # trim
  str = str.toLowerCase()
  
  # remove accents, swap ñ for n, etc
  from = "àáäâèéëêìíïîòóöôùúüûñç·/_,:;"
  to = "aaaaeeeeiiiioooouuuunc------"
  i = 0
  l = from.length

  while i < l
    str = str.replace(new RegExp(from.charAt(i), "g"), to.charAt(i))
    i++
  # remove invalid chars
  # collapse whitespace and replace by -
  str = str.replace(/[^a-z0-9 -]/g, "").replace(/\s+/g, "-").replace(/-+/g, "-") # collapse dashes
  return str

pimatic.autoFillId = (nameObservable, idObservable, actionObservable) =>
  lastGeneratedId = ""
  nameObservable.subscribe( (newName) =>
    if actionObservable() isnt 'add'
      lastGeneratedId = ""
      return
    currentId = idObservable()
    generatedId = pimatic.makeIdFromName(newName)
    if currentId is lastGeneratedId or currentId.length is 0
      idObservable(generatedId)
    lastGeneratedId = generatedId
  )
  return

window.__ = (text, args...) -> 
  translated = text
  if locale[text]? then translated = locale[text]
  else console.log 'no translation yet:', text
    
  for a in args
    translated = translated.replace /%s/, a
  return translated

unless window.console? then window.console = { log: -> }

TraceKit.report.subscribe( (errorReport) => 

  for entry in errorReport.stack
    if entry.context?
      for c,i in entry.context
        if c.length > 200 
          entry.context[i] = c.substring(0, 200) + '...'
  # add infos about storage
  # errorReport.pimaticData = pimatic.storage?.get('pimatic')
  $.ajax(
    url: '/client-error'
    type: 'POST'
    global: no
    data: {
      error: errorReport
    }
  )
)

