# edit-plugin-page
# --------------

merge = Array.prototype.concat
LazyLoad.js(merge.apply(scripts.jsonschemeeditor))

$(document).on("pagebeforecreate", '#edit-plugin-page', (event) ->
  if pimatic.pages.editPlugin? then return
  
  class EditPluginViewModel

    action: ko.observable('add')
    pluginName: ko.observable('')
    pluginConfig: ko.observable({})
    configSchema: ko.observable(null)

    constructor: ->
      @pageTitle = ko.computed( => __('Plugin Config') )
      pimatic.autoFillId(@deviceName, @deviceId, @action)

    afterRenderItem: (elements, device) ->
      handleHTML = $('#sortable-handle-template').text()
      $(elements).find("a").before($(handleHTML))

    resetFields: () ->
      @pluginName('')
      @pluginConfig({})
      @configSchema(null)

    onSubmit: ->
      # deviceConfig = JsonSchemeEditor.unwrap @deviceConfig()
      # deviceConfig.id = @deviceId()
      # deviceConfig.name = @deviceName()
      # deviceConfig.class = @deviceClass()
      # # console.log deviceConfig
      # (
      #   switch @action()
      #     when 'add' then pimatic.client.rest.addDeviceByConfig({deviceConfig})
      #     when 'update' then pimatic.client.rest.updateDeviceByConfig({deviceConfig})
      #     else throw new Error("Illegal devicedevice action: #{action()}")
      # ).done( (data) ->
      #   if data.success then $.mobile.changePage '#devices-page', {transition: 'slide', reverse: true}   
      #   else alert data.error
      # ).fail(ajaxAlertFail)
      # return false

  try
    pimatic.pages.editPlugin = new EditPluginViewModel()
  catch e
    TraceKit.report(e)
  return
)

$(document).on("pagebeforeshow", '#edit-plugin-page', (event) ->
  # pimatic.client.rest.getDeviceClasses({}).done( (result) =>
  #   if result.success
  #     deviceClasses = [""].concat result.deviceClasses
  #     pimatic.pages.editPlugin.deviceClasses(deviceClasses)
  # )
)

$(document).on("pagecreate", '#edit-plugin-page', (event) ->
  try
    ko.applyBindings(pimatic.pages.editPlugin, $('#edit-plugin-page')[0])
  catch e
    TraceKit.report(e)
)


$(document).on("pagebeforeshow", '#edit-device-page', (event) ->
  editPluginPage = pimatic.pages.editPlugin
  params = jQuery.mobile.pageParams
  jQuery.mobile.pageParams = {}
  # if params?.action is "update"
  #   device = params.device
  #   editPluginPage.action('update')
  #   editPluginPage.deviceId(device.id)
  #   editPluginPage.deviceName(device.name())
  #   editPluginPage.deviceClass(null)
  #   editPluginPage.configSchema(null)
  #   editPluginPage.deviceConfig(device.config)
  #   deviceClasses = pimatic.pages.editPlugin.deviceClasses()
  #   unless device.config.class in deviceClasses
  #     deviceClasses.push device.config.class
  #     editPluginPage.deviceClasses(deviceClasses)
  #   editPluginPage.deviceClass(device.config.class)
  # else
  #   editPluginPage.resetFields()
  #   editPluginPage.action('add')
  # return
)
