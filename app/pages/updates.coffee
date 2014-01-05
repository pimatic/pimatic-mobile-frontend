# updates-page
# ---------

outdatedPlugins = null
pimaticUpdate = null

$(document).on "pagebeforeshow", '#updates', (event) ->
  $('#install-updates').hide()

$(document).on "pageshow", '#updates', (event) ->
  searchForPimaticUpdate().done ->
    searchForOutdatedPlugins().done ->
      if pimaticUpdate isnt false or outdatedPlugins.length isnt 0
        $('#install-updates').show()

  $('#updates').on "click", '#install-updates', (event, ui) ->
    modules = (if pimaticUpdate then ['pimatic'] else [])
    modules.concate (p.name for p in outdatedPlugins)
    
    $.post("/api/update", modules: modules).done( (data) ->
      console.log data
    ).fail(ajaxAlertFail)
  


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
    outdatedPlugins = data.isOutdated
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
    pimaticUpdate = data.outdated
    return
  ).fail(ajaxAlertFail)