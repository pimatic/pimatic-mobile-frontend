# edit-variable-page
# --------------

$(document).on("pagebeforecreate", (event) ->
  if pimatic.pages.editVariable? then return

  class EditVariableViewModel

    autocompleteAjax: null
    autocompleEnabled: no

    action: ko.observable('add')
    variableName: ko.observable('')
    variableValue: ko.observable('')

    constructor: ->
      @pageTitle = ko.computed( => 
        return (if @action() is 'add' then __('Add new variable') else __('Edit variable'))
      )

    resetFields: () ->
      @variableName('')
      @variableValue('')

    onSubmit: ->
      $.post("/api/variable/#{@variableName()}/#{@action()}", 
        name: @variableName()
        value: @variableValue()
      ).done( (data) ->
          if data.success then $.mobile.changePage '#index', {transition: 'slide', reverse: true}   
          else alert data.error
      ).fail(ajaxAlertFail)
      return false

    onRemove: ->
      $.get("/api/variable/#{@variableName()}/remove")
        .done( (data) ->
          if data.success then $.mobile.changePage '#index', {transition: 'slide', reverse: true}   
          else alert data.error
        ).fail(ajaxAlertFail)
      return false

  pimatic.pages.editVariable = new EditVariableViewModel()
  return
)

$(document).on("pagecreate", '#edit-variable', (event) ->
  ko.applyBindings(pimatic.pages.editVariable, $('#edit-variable')[0])
)


