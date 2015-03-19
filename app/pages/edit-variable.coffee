# edit-variable-page
# --------------

$(document).on("pagebeforecreate", '#edit-variable-page', (event) ->
  if pimatic.pages.editVariable? then return

  class EditVariableViewModel

    autocompleteAjax: null
    autocompleEnabled: no

    action: ko.observable('add')
    variableName: ko.observable('')
    variableValue: ko.observable('')
    variableType: ko.observable('value')
    variableUnit: ko.observable('')

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
      @variableUnit('')


    onSubmit: ->
      unless pimatic.isValidVariableName(@variableName())
        alert __(pimatic.invalidVariableNameMessage)
        return

      params = {
        name: @variableName()
        type: @variableType()
        valueOrExpression: @variableValue()
        unit: @variableUnit()
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
      really = confirm(__("Do you really want to delete the %s variable?", @variableName()))
      if really
        pimatic.client.rest.removeVariable({name: @variableName()})
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

$(document).on("pagecreate", '#edit-variable-page', (event) ->
  try
    ko.applyBindings(pimatic.pages.editVariable, $('#edit-variable-page')[0])
  catch e
    TraceKit.report(e)
)

$(document).on("pagebeforeshow", '#edit-variable-page', (event) ->
  editVariablePage = pimatic.pages.editVariable
  params = jQuery.mobile.pageParams
  jQuery.mobile.pageParams = {}
  if params?.action is "update"
    variable = params.variable
    editVariablePage.action('update')
    editVariablePage.variableName(variable.name)
    editVariablePage.variableValue(
      if variable.type() is 'value' then variable.value() else variable.exprInputStr()
    )
    editVariablePage.variableType(variable.type())
    editVariablePage.variableUnit(variable.unit())
  else
    editVariablePage.resetFields()
    editVariablePage.action('add')
  return
)
