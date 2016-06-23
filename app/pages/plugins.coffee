# plugins-page
# ---------
tc = pimatic.tryCatch

$(document).on("pagebeforecreate", '#plugins-page', (event) ->
  if pimatic.pages.plugins? then return

  class PluginsViewModel

    @mapping = {
      $default: 'ignore'
      installedPlugins:
        $key: 'name'
        $itemOptions:
          $default: 'copy'
          loaded: 'observe'
          activated: 'observe'
      browsePlugins:
        $key: 'name'
        $itemOptions:
          $default: 'copy'
          installed: 'observe'
          loaded: 'observe'
          activated: 'observe'
    }

    restartRequired: ko.observable(false)

    updateFromJs: (data) ->
      ko.mapper.fromJS(data, PluginsViewModel.mapping, this)

    constructor: ->
      @hasPermission = pimatic.hasPermission
      @updateProcessStatus = pimatic.updateProcessStatus
      @updateFromJs(installedPlugins: [], browsePlugins: [])

      @updateListView = ko.computed( tc =>
        @installedPlugins()
        pimatic.try( => $('#plugin-list').listview('refresh') )
      ).extend(rateLimit: {timeout: 1, method: "notifyWhenChangesStop"})

      oldStatus = @updateProcessStatus()
      @updateProcessStatus.subscribe( (newStatus) =>
        if oldStatus is "running" and newStatus = "done"
          @refresh()
        oldStatus = newStatus
      )

    onActivateClick: (plugin) =>
      unless @hasPermission('plugins', 'write')
        pimatic.showToast(__("Sorry, you have no permissions to avtivate the plugin."))
        return false
      pimatic.client.rest.getPluginConfig({pluginName: plugin.name}).always( (result) =>
        if result.success?
          unless result.config?
            jQuery.mobile.pageParams = {action: 'add', pluginName: plugin.name}
            jQuery.mobile.changePage('#edit-plugin-page')
          else
            pimatic.client.rest.setPluginActivated({
              pluginName: plugin.name
              active: true
            }).done( (result) =>
              if result.success
                plugin.activated(true)
                @restartRequired(true)
            )
      )
      return false

    onDeactivateClick: (plugin) =>
      unless @hasPermission('plugins', 'write')
        pimatic.showToast(__("Sorry, you have no permissions to deactivate the plugin."))
        return false
      pimatic.client.rest.setPluginActivated({
        pluginName: plugin.name
        active: false
      }).done( (result) =>
        if result.success
          plugin.activated(false)
          @restartRequired(true)
      ).fail( ajaxAlertFail)

    onUninstallClick: (plugin) =>
      unless @hasPermission('plugins', 'write')
        pimatic.showToast(__("Sorry, you have no permissions to uninstall the plugin."))
        return false
      really = confirm(__("Do you really want to uninstall the %s plugin?", plugin.name))
      if really
        pimatic.client.rest.uninstallPlugin({
          name: "pimatic-#{plugin.name}"
        }).done( =>
          @restartRequired(true)
          @refresh()
          removeConfig = confirm(__("Do you want to remove all config options as well?"))
          if removeConfig
            pimatic.client.rest.removePluginFromConfig({
              pluginName: plugin.name
            }).done( => @refresh() ).fail( ajaxAlertFail)
          else
            pimatic.client.rest.setPluginActivated({
              pluginName: plugin.name
              active: false
            }).done( => @refresh() ).fail( ajaxAlertFail)
        ).fail( ajaxAlertFail)

    onSettingsClick: (plugin) =>
      unless @hasPermission('plugins', 'write')
        pimatic.showToast(__("Sorry, you have no permissions to edit the plugin."))
        return false
      jQuery.mobile.pageParams = {action: 'update', pluginName: plugin.name}
      return true

    onInstallClick: (plugin) =>
      unless @hasPermission('updates', 'write')
        pimatic.showToast(__("Sorry, you have no permissions to install the plugin."))
        return false
      modules = ["pimatic-#{plugin.name}"]
      pimatic.client.rest.installUpdatesAsync({modules})
      .fail( (jqXHR, textStatus, errorThrown) =>
        # ignore timeouts:
        if textStatus isnt "timeout"
          ajaxAlertFail(jqXHR, textStatus, errorThrown)
      )

    getInstalledPluginsWithInfo: ->
      pimatic.client.rest.getInstalledPluginsWithInfo().done( (data) =>
        # save the plugins in installedPlugins
        @updateFromJs(installedPlugins: data.plugins)
      ).fail(ajaxAlertFail)

    searchForPluginsWithInfo: ->
      pimatic.client.rest.searchForPluginsWithInfo().done( (data) =>
        # save the plugins in installedPlugins
        @updateFromJs(browsePlugins: data.plugins)
      ).fail(ajaxAlertFail)

    doesRequireRestart: ->
      pimatic.client.rest.doesRequireRestart().done( (data) =>
        # save the plugins in installedPlugins
        @restartRequired(data.restartRequired)
      ).fail(ajaxAlertFail)

    refresh: =>
      @getInstalledPluginsWithInfo()
      @searchForPluginsWithInfo()
      @doesRequireRestart()

  try
    pimatic.pages.plugins = new PluginsViewModel()
  catch e
    TraceKit.report(e)
  return
)

$(document).on("pagecreate", '#plugins-page', (event) ->
  try
    ko.applyBindings(pimatic.pages.plugins, $('#plugins-page')[0])
  catch e
    TraceKit.report(e)

  $('#plugins-page').on "click", '.restart-now', (event, ui) ->
    pimatic.client.rest.restart({}).fail(ajaxAlertFail)

  pimatic.socket.on('connect', () ->
    console.log()
  )
)

$(document).on "pageinit", '#plugins-page', (event) ->
  pluginPage = pimatic.pages.plugins
  # Get all installed Plugins
  pluginPage.refresh()

$(document).on "pageshow","#plugins-page", ->
  pimatic.socket.on('connect', pimatic.pages.plugins.refresh)

$(document).on "pagebeforehide","#plugins-page", ->
  pimatic.socket.off('connect', pimatic.pages.plugins.refresh)



  # $('#plugins-page').on "click", '#plugin-do-action', (event, ui) ->
  #   val = $('#select-plugin-action').val()
  #   if val is 'select' then return alert __('Please select a action first')
  #   selected = []
  #   for ele in $ '#plugin-list input[type="checkbox"]'
  #     ele = $ ele
  #     if ele.is(':checked')
  #       selected.push(ele.data 'plugin-name')
  #   (switch val
  #     when 'add' then pimatic.client.rest.addPluginsToConfig({
  #         pluginNames: selected
  #       })
  #     when 'remove' then pimatic.client.rest.removePluginsFromConfig({
  #       pluginNames: selected
  #     })
  #   ).done( (data) ->
  #     past = (if val is 'add' then 'added' else 'removed')
  #     pimatic.showToast data[past].length + __(" plugins #{past}") + "." +
  #      (if data[past].length > 0 then " " + __("Please restart pimatic.") else "")
  #     pimatic.pages.plugins.uncheckAllPlugins()
  #     return
  #   ).fail(ajaxAlertFail)

  # $('#plugins-page').on "click", '.restart-now', (event, ui) ->
  #   pimatic.client.rest.restart({}).fail(ajaxAlertFail)


# $(document).on "pagebeforeshow", '#plugins-page', (event) ->
#   pimatic.try => $('#select-plugin-action').val('select').selectmenu('refresh')

# plugins-browse-page
# ---------

# $(document).on "pageinit", '#plugins-browse', (event) ->

#   pimatic.showToast __('pimatic is searching for plugins for you...')

#   pimatic.client.rest.searchForPluginsWithInfo().done( (data) ->
#     $('#plugin-browse-list').empty()
#     pimatic.pages.plugins.allPlugins = data.plugins
#     for p in data.plugins
#       pimatic.pages.plugins.addBrowsePlugin(p)
#       if p.isNewer
#         $("#plugin-#{p.name} .update-available").show()
#       $('#plugin-browse-list').listview("refresh")
#     pimatic.pages.plugins.disableInstallButtons()
#   ).fail(ajaxAlertFail)

#   $('#plugin-browse-list').on "click", '.add-to-config', (event, ui) ->
#     li = $(this).parent('li')
#     plugin = li.data('plugin')
#     pimatic.client.rest.addPluginsToConfig(pluginNames: [plugin.name]).done( (data) ->
#       text = null
#       if data.added.length > 0
#         text = __('Added %s to the config. Plugin will be auto installed on next start.', 
#                   plugin.name)
#         text +=  " " + __("Please restart pimatic.")
#         li.find('.add-to-config').addClass('ui-disabled') 
#       else
#         text = __('The plugin %s was already in the config.', plugin.name)
#       pimatic.showToast text
#       return
#     ).fail(ajaxAlertFail)
#     return

# pimatic.pages.plugins =
#   installedPlugins: null
#   allPlugins: null

#   uncheckAllPlugins: () ->
#     for ele in $ '#plugin-list input[type="checkbox"]'
#       $(ele).prop("checked", false).checkboxradio("refresh")
#     return



#   disableInstallButtons: () ->
#     if pimatic.pages.plugins.allPlugins?
#       for p in pimatic.pages.plugins.allPlugins
#         if p.installed 
#           $("#plugin-browse-list #plugin-browse-#{p.name} .add-to-config").addClass('ui-disabled') 
#     return

#   addBrowsePlugin: (plugin) ->
#     id = "plugin-browse-#{plugin.name}"
#     li = $ $('#plugin-browse-template').html()
#     li.data('plugin', plugin)
#     li.attr('id', id)
#     li.find('.name').text(plugin.name)
#     li.find('.description').text(plugin.description)
#     li.find('.version').text(plugin.version)
#     if plugin.active then li.find('.active').show()
#     else li.find('.active').hide()
#     if plugin.installed then li.find('.installed').show()
#     else li.find('.installed').hide()
#     $('#plugin-browse-list').append li
#     return
