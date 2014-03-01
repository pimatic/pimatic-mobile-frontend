# updates-page
# ---------

$(document).on "pagebeforeshow", '#updates', (event) ->
  $('#updates #install-updates').hide()
  $('#updates .restart-now').hide()

$(document).on "pageshow", '#updates', (event) ->
  updatesPage = pimatic.pages.updates
  updatesPage.searchForPimaticUpdate().done ->
    updatesPage.searchForOutdatedPlugins().done ->
      if updatesPage.pimaticUpdate isnt false or updatesPage.outdatedPlugins.length isnt 0
        $('#install-updates').show()


$(document).on "pagecreate", '#updates', (event) ->
  
  $('#updates').on "click", '#install-updates', (event, ui) ->
    updatesPage = pimatic.pages.updates
    modules = (if updatesPage.pimaticUpdate then ['pimatic'] else [])
    modules = modules.concat (p.plugin for p in updatesPage.outdatedPlugins)

    $.ajax(
      url: "/api/update"
      type: 'POST'
      data: modules: modules
      timeout: 1000000 #ms
    ).done( (data) ->
      $('#updates #install-updates').hide()
      if data.success
        $('#updates .message').append $('<p>')
          .text(__('Updates were successful. Please restart pimatic.'))
        $('#updates .restart-now').show()
    ).fail(ajaxAlertFail)

  $('#updates').on "click", '.restart-now', (event, ui) ->
    $.get('/api/restart').fail(ajaxAlertFail)
  
pimatic.pages.updates =
  outdatedPlugins: null
  pimaticUpdate: null

  searchForPimaticUpdate: ->
    $('#updates .message').text __('pimatic is searching for updates...')
    return $.ajax(
      url: "/api/outdated/pimatic"
      timeout: 300000 #ms
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
      pimatic.pages.updates.pimaticUpdate = data.isOutdated
      return 
    ).fail(ajaxAlertFail)

  searchForOutdatedPlugins: ->
    return $.ajax(
      url: "/api/outdated/plugins"
      timeout: 300000 #ms
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
      pimatic.pages.updates.outdatedPlugins = data.outdated
      return
    ).fail(ajaxAlertFail)