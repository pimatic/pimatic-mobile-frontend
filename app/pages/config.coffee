# updates-page
# ---------


# log-page
# ---------

$(document).on("pagecreate", '#config', (event) ->

  class ConfigViewModel
    config: ko.observable('')
    mode: ko.observable('')
    locked: ko.observable(true)

    constructor: -> #nop
      self = this
      scripts = $($('#editor-scripts-template').text())
      scripts.appendTo('head')
      soruce = $(scripts[1]).attr('src')
      $.getScript(soruce, ( data, textStatus, jqxhr ) =>
        container= $('#config-editor')[0]
        # capture mode changes
        orgSetMode = JSONEditor.prototype.setMode
        JSONEditor.prototype.setMode = (mode) ->
          result = orgSetMode.call(this, mode)
          self.mode(mode)
          return result

        ko.computed( =>
          mode = @mode()
          if mode is 'code'
            @editor?.editor.setReadOnly(@locked())
          if mode is 'view'
            @editor?.modes = ['tree', 'code']
            unless @locked()
              @editor?.setMode('tree')
          if mode is 'tree'
            @editor?.modes = ['view', 'code']
            if @locked()
              @editor?.setMode('view')
        )

        @editor = new JSONEditor(container, {
          mode: 'view',
          modes: ['view', 'code'] 
        })
        @getConfig()
        @config.subscribe( (value) =>
          @editor.set(value)
        )
      )

      @lockButton = ko.computed( => 
        locked = @locked()
        return {
          icon: (if locked then 'gear' else 'delete')
          text: (if locked then __('Edit') else __('Cancel'))
        }
      )

    toggleLock: ->
      if @locked()
        swal({
          type: "prompt"
          title: "Unlock"
          text: "Please Enter your password to unlock the config page:"
          promptPlaceholder: "Password"
          promptDefaultValue: ""
          promptInputType: "password"
        }, (value) => 
          return pimatic.client.rest.getConfig({password: value}).done( (data) =>
            @config(data.config)
            @locked(no)
            return 
          ).fail(ajaxAlertFail)
        )
      else
        pimatic.client.rest.getConfig({}).done( (data) =>
          @config(data.config)
          @locked(yes)
          return 
        ).fail(ajaxAlertFail)
      
    getConfig: ->
      return pimatic.client.rest.getConfig({}).done( (data) =>
        @config(data.config)
        return 
      ).fail(ajaxAlertFail)

    updateConfigClicked: =>
      try
        swal({
          title: "Are you sure?",
          text: "pimatic will be restarted after the config was changed!",
          type: "warning",
          showCancelButton: true,
          confirmButtonText: "Yes",
        }, =>
          config = @editor.get()
          pimatic.client.rest.updateConfig(config: config).fail(ajaxAlertFail)
          @locked(yes)
        )
      catch e
        alert e

  try
    pimatic.pages.config = configPage = new ConfigViewModel()
    ko.applyBindings(configPage, $('#config')[0])
  catch e
    TraceKit.report(e)
  return
)

$(document).on "pagehide", '#config', (event) ->
  try
    configPage = pimatic.pages.config
    if configPage.editor?
      configPage.config(null)
  catch e
    TraceKit.report(e)

$(document).on "pageshow", '#config', (event) ->
  try
    configPage = pimatic.pages.config
    if configPage.editor? and !configPage.config()?
      configPage.getConfig()
  catch e
    TraceKit.report(e)