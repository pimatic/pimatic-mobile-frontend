# plugins-page
# ---------

$(document).on "pageinit", '#plugins', (event) ->
  # Get all installed Plugins
  pimatic.client.rest.getInstalledPluginsWithInfo().done( (data) ->
    console.log data
    $('#plugin-list').empty()
    # save the plugins in installedPlugins
    pimatic.pages.plugins.installedPlugins = data.plugins
    # and add them to the list.
    pimatic.pages.plugins.addPlugin(p) for p in data.plugins
    $('#plugin-list').listview("refresh")
    $("#plugin-list input[type='checkbox']").checkboxradio()
  ).fail( ajaxAlertFail)

  $('#plugins').on "click", '#plugin-do-action', (event, ui) ->
    val = $('#select-plugin-action').val()
    if val is 'select' then return alert __('Please select a action first')
    selected = []
    for ele in $ '#plugin-list input[type="checkbox"]'
      ele = $ ele
      if ele.is(':checked')
        selected.push(ele.data 'plugin-name')
    $.post("/api/plugins/#{val}", plugins: selected)
      .done( (data) ->
        past = (if val is 'add' then 'added' else 'removed')
        pimatic.showToast data[past].length + __(" plugins #{past}") + "." +
         (if data[past].length > 0 then " " + __("Please restart pimatic.") else "")
        pimatic.pages.plugins.uncheckAllPlugins()
        return
      ).fail(ajaxAlertFail)

  $('#plugins').on "click", '.restart-now', (event, ui) ->
    $.get('/api/restart').fail(ajaxAlertFail)


$(document).on "pagebeforeshow", '#plugins', (event) ->
  pimatic.try => $('#select-plugin-action').val('select').selectmenu('refresh')

# plugins-browse-page
# ---------
$(document).on "pageinit", '#plugins-browse', (event) ->

  pimatic.showToast __('pimatic is searching for plugins for you...')

  $.ajax(
    url: "/api/plugins/search"
    timeout: 300000 #ms
  ).done( (data) ->
    $('#plugin-browse-list').empty()
    pimatic.pages.plugins.allPlugins = data.plugins
    for p in data.plugins
      pimatic.pages.plugins.addBrowsePlugin(p)
      if p.isNewer
        $("#plugin-#{p.name} .update-available").show()
      $('#plugin-browse-list').listview("refresh")
    pimatic.pages.plugins.disableInstallButtons()
  ).fail(ajaxAlertFail)

  $('#plugin-browse-list').on "click", '.add-to-config', (event, ui) ->
    li = $(this).parent('li')
    plugin = li.data('plugin')
    $.post("/api/plugins/add", plugins: [plugin.name])
      .done( (data) ->
        text = null
        if data.added.length > 0
          text = __('Added %s to the config. Plugin will be auto installed on next start.', 
                    plugin.name)
          text +=  " " + __("Please restart pimatic.")
          li.find('.add-to-config').addClass('ui-disabled') 
        else
          text = __('The plugin %s was already in the config.', plugin.name)
        pimatic.showToast text
        return
      ).fail(ajaxAlertFail)
    return

pimatic.pages.plugins =
  installedPlugins: null
  allPlugins: null

  uncheckAllPlugins: () ->
    for ele in $ '#plugin-list input[type="checkbox"]'
      $(ele).prop("checked", false).checkboxradio("refresh")
    return

  addPlugin: (plugin) ->
    id = "plugin-#{plugin.name}"
    li = $ $('#plugin-template').html()
    li.attr('id', id)
    checkBoxId = "cb-#{id}"
    li.find('.name').text(plugin.name)
    li.find('.description').text(plugin.description)
    li.find('.version').text(plugin.version)
    li.find('.homepage').text(plugin.homepage).attr('href', plugin.homepage)
    if plugin.active then li.find('.active').show()
    else li.find('.active').hide()
    li.find('.update-available').hide()
    li.find("input[type='checkbox']").attr('id', checkBoxId).attr('name', checkBoxId)
      .data('plugin-name', plugin.name)
    $('#plugin-list').append li
    return

  disableInstallButtons: () ->
    if pimatic.pages.plugins.allPlugins?
      for p in pimatic.pages.plugins.allPlugins
        if p.installed 
          $("#plugin-browse-list #plugin-browse-#{p.name} .add-to-config").addClass('ui-disabled') 
    return

  addBrowsePlugin: (plugin) ->
    id = "plugin-browse-#{plugin.name}"
    li = $ $('#plugin-browse-template').html()
    li.data('plugin', plugin)
    li.attr('id', id)
    li.find('.name').text(plugin.name)
    li.find('.description').text(plugin.description)
    li.find('.version').text(plugin.version)
    if plugin.active then li.find('.active').show()
    else li.find('.active').hide()
    if plugin.installed then li.find('.installed').show()
    else li.find('.installed').hide()
    $('#plugin-browse-list').append li
    return
