# updates-page
# ---------


# log-page
# ---------

$(document).on("pagecreate", '#config', (event) ->

  class ConfigViewModel
    config: ko.observable('')

    constructor: -> #nop
      scripts = $($('#editor-scripts-template').text())
      scripts.appendTo('head')
      soruce = $(scripts[1]).attr('src')
      $.getScript(soruce, ( data, textStatus, jqxhr ) =>
        container= $('#config-editor')[0]
        editor = new JSONEditor(container, {
          mode: 'tree',
          modes: ['tree', 'code'] 
        })
        @getConfig()
        @config.subscribe( (value) =>
          editor.set(value);
        )
      )
      
    getConfig: ->
      return pimatic.client.rest.getConfig().done( (data) =>
        @config(data.config)
        return 
      ).fail(ajaxAlertFail)

  try
    pimatic.pages.config = configPage = new ConfigViewModel()
    ko.applyBindings(configPage, $('#config')[0])
  catch e
    TraceKit.report(e)
  return
)

# $(document).on "pageshow", '#config', (event) ->
#   try
#     config = pimatic.pages.config
#     config.getConfig()
#   catch e
#     TraceKit.report(e)