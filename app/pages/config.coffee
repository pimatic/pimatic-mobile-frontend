# config-page
# ---------

merge = Array.prototype.concat
LazyLoad.js(merge.apply(scripts.editor))
LazyLoad.css(merge.apply(styles.editor))

$(document).on("pagecreate", '#config-page', (event) ->

  class ConfigViewModel
    config: ko.observable('')
    mode: ko.observable('')
    locked: ko.observable(true)

    constructor: -> #nop
      self = this
      container = $('#config-editor')[0]
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
          if @locked()
            $('#config-editor .ace_content').addClass('readonly')
          else
            $('#config-editor .ace_content').removeClass('readonly')
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
        mode: 'code',
        modes: ['view', 'code'] 
      })
      @editor.editor.setReadOnly(true);
      $('#config-editor .ace_content').addClass('readonly')
      @getConfig()
      @config.subscribe( (value) =>
        @editor.set(value)
      )

      @lockButton = ko.computed( => 
        locked = @locked()
        return {
          icon: (if locked then 'gear' else 'delete')
          text: (if locked then __('Edit') else __('Cancel'))
        }
      )

      $.mobile.document.on "pagebeforechange",  (event, data) => 
        if data.options.fromPage?.is('#config-page') and (not @locked())
          swal({
            title: "Discard all changes?",
            text: "If you leave the page all unsaved changes will be lost, continue?",
            type: "warning",
            showCancelButton: true,
            confirmButtonText: "Continue",
            closeOnConfirm: true
          }).then( =>
            @locked(true)
            $.mobile.pageContainer.pagecontainer("change", data.toPage, {options: data.options})
          )
          event.preventDefault()
          return false
        return true
        
    toggleLock: ->
      if @locked()
        swal({
          type: "question"
          title: "Unlock"
          text: "Please Enter your password to unlock the config page:"
          inputPlaceholder: "Password"
          inputValue: ""
          input: "password"
        }).then( (value) => 
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
      swal({
        title: "Are you sure?",
        text: "pimatic will be restarted after the config was changed!",
        type: "warning",
        showCancelButton: true,
        confirmButtonText: "Yes",
        closeOnConfirm: false
      }).then( =>
        try
          config = @editor.get()
          pimatic.client.rest.updateConfig(config: config).done( =>
            swal("Restarting", "Config seems to be valid, restarting...", "success")
            @locked(yes)
          ).fail(ajaxAlertFail).fail()
        catch err
          swal("Oops...", err, "error")
      )

  try
    pimatic.pages.config = configPage = new ConfigViewModel()
    ko.applyBindings(configPage, $('#config-page')[0])
  catch e
    TraceKit.report(e)
  return
)

$(document).on "pagehide", '#config-page', (event) ->
  try
    configPage = pimatic.pages.config
    if configPage.editor?
      configPage.config(null)
  catch e
    TraceKit.report(e)

$(document).on "pageshow", '#config-page', (event) ->
  try
    configPage = pimatic.pages.config
    if configPage.editor? and !configPage.config()?
      configPage.getConfig()
  catch e
    TraceKit.report(e)