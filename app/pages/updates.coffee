# updates-page
# ---------

outdatedPlugins = null
pimaticUpdate = null

$(document).on "pagebeforeshow", '#updates', (event) ->
  $('#updates #install-updates').hide()
  $('#updates #restart-now').hide()

$(document).on "pageshow", '#updates', (event) ->
  searchForPimaticUpdate().done ->
    searchForOutdatedPlugins().done ->
      if pimaticUpdate isnt false or outdatedPlugins.length isnt 0
        $('#install-updates').show()

  $('#updates').on "click", '#install-updates', (event, ui) ->
    modules = (if pimaticUpdate then ['pimatic'] else [])
    modules = modules.concat (p.plugin for p in outdatedPlugins)

    $.ajax(
      url: "/api/update"
      type: 'POST'
      data: modules: modules
      timeout: 600000 #ms
    ).done( (data) ->
      $('#updates #install-updates').hide()
      if data.success
        $('#updates .message').append $('<p>').text(__('Updates was successful. Please restart pimatic.'))
        $('#updates #restart-now').show()
    ).fail(ajaxAlertFail)

    $('#updates').on "click", '#restart-now', (event, ui) ->
      $.get('/api/restart').fail(ajaxAlertFail)
  


searchForPimaticUpdate = ->
  $('#updates .message').text __('Searching for updates...')
  $.ajax(
    url: "/api/outdated/pimatic"
    timeout: 30000 #ms
  ).done( (data) ->
    $('#updates .message').text ''
    if data.isOutdated is false
       $('#updates .message').append $('<p>').text(__('pimatic is up to date.'))
    else
      $('#updates .message').append $('<p>').text(
        __('Found update for %s: current version is %s, latest version is: %s', 
          'pimatic', data.isOutdated.current, data.isOutdated.latest
        )
      ) 
    pimaticUpdate = data.isOutdated
    return 
  ).fail(ajaxAlertFail)

searchForOutdatedPlugins = ->
  $.ajax(
    url: "/api/outdated/plugins"
    timeout: 30000 #ms
  ).done( (data) ->
    if data.outdated.length is 0
      $('#updates .message').append $('<p>').text __('All plugins are up to date')
    else
      for p in data.outdated
        $('#updates .message').append $('<p>').text(
          __('Found update for %s: current version is %s, latest version is: %s', 
            p.plugin, p.current, p.latest
          )
        ) 
    outdatedPlugins = data.outdated
    return
  ).fail(ajaxAlertFail)