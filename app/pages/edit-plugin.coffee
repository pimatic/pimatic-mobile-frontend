# edit-plugin-page
# --------------

merge = Array.prototype.concat
LazyLoad.js(merge.apply(scripts.jsonschemaeditor))

$(document).on("pagebeforecreate", '#edit-plugin-page', (event) ->
  if pimatic.pages.editPlugin? then return

  class EditPluginViewModel

    action: ko.observable('add')
    pluginName: ko.observable('')
    pluginConfig: ko.observable({})
    configSchema: ko.observable(null)

    constructor: ->
      @pageTitle = ko.computed( => __('Plugin Config') )

      @pluginName.subscribe( (pluginName) =>
        if pluginName? and typeof pluginName is "string" and pluginName.length > 0
          pimatic.client.rest.getPluginConfigSchema({pluginName: "pimatic-#{pluginName}"}).done( (result) =>
            if result.success?
              schema = result.configSchema
              delete schema.properties.active
              delete schema.properties.plugin
              unwraped = jsonschemaeditor.unwrap(@pluginConfig())
              rewraped = jsonschemaeditor.wrap(schema, unwraped)
              @configSchema(null)
              @pluginConfig(rewraped())
              jsonschemaeditor.enhanceSchema schema, null
              schema.name = pluginName
              @configSchema(schema)
          )
        else
          @configSchema(null)
      )

    afterRenderItem: (elements, device) ->
      handleHTML = $('#sortable-handle-template').text()
      $(elements).find("a").before($(handleHTML))

    resetFields: () ->
      @pluginName('')
      @pluginConfig({})
      @configSchema(null)

    onSubmit: ->
      pluginName = @pluginName()
      pluginConfig = jsonschemaeditor.unwrap @pluginConfig()
      errors = []
      jsonschemaeditor.validate @configSchema(), pluginConfig, errors
      if errors.length > 0
        alert(errors.join("\n"))
        return
      pluginConfig.plugin = pluginName
      pluginConfig.active = true
      pimatic.client.rest.updatePluginConfig({
        pluginName: pluginName,
        config: pluginConfig
      }).done( (data) ->
        pluginPage = pimatic.pages.plugins
        # Get all installed Plugins
        pluginPage.refresh()
        pluginPage.restartRequired(true)
        if data.success then $.mobile.changePage '#plugins-page', {transition: 'slide', reverse: true}
        else alert data.error
      ).fail(ajaxAlertFail)
      return false

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


$(document).on("pagebeforeshow", '#edit-plugin-page', (event) ->
  editPluginPage = pimatic.pages.editPlugin
  params = jQuery.mobile.pageParams
  jQuery.mobile.pageParams = {}
  if params?
    editPluginPage.pluginName(null)
    editPluginPage.configSchema(null)
    pimatic.client.rest.getPluginConfig({pluginName: params.pluginName}).always( (result) =>
      if result.success?
        config = result.config || {}
        editPluginPage.pluginConfig(config)
        editPluginPage.pluginName(params.pluginName)
    )
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
