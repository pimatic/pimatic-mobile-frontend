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
    variableType: ko.observable('value')

    constructor: ->
      @pageTitle = ko.computed( => 
        return (if @action() is 'add' then __('Add new variable') else __('Edit variable'))
      )

      @valueLabelText = ko.computed( => 
        return if @variableType() is 'value' then __('Value') else __('Expr.') 
      )

    resetFields: () ->
      @variableName('')
      @variableValue('')
      @variableType('value')


    onSubmit: ->

      params = {
        name: @variableName()
        type: @variableType()
        valueOrExpression: @variableValue()
      }

      (
        switch @action()
          when 'add' then pimatic.client.rest.addVariable(params)
          when 'update' then pimatic.client.rest.updateVariable(params)
          else throw new Error("Illegal variable action: #{action()}")
      ).done( (data) ->
        if data.success then $.mobile.changePage '#variables-page', {transition: 'slide', reverse: true}   
        else alert data.error
      ).fail(ajaxAlertFail)
      return false

    onRemove: ->
      $.get("/api/variable/#{@variableName()}/remove")
        .done( (data) ->
          if data.success then $.mobile.changePage '#variables-page', {transition: 'slide', reverse: true}   
          else alert data.error
        ).fail(ajaxAlertFail)
      return false

  try
    pimatic.pages.editVariable = new EditVariableViewModel()
  catch e
    TraceKit.report(e)
  return
)

$(document).on("pagecreate", '#edit-variable', (event) ->
  try
    ko.applyBindings(pimatic.pages.editVariable, $('#edit-variable')[0])
  catch e
    TraceKit.report(e)
)


