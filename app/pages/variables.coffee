# index-page
# ----------
tc = pimatic.tryCatch

$(document).on( "pagebeforecreate", '#variables-page', tc (event) ->

  class VariablesViewModel

    enabledEditing: ko.observable(no)
    ruleItemCssClass: ko.observable('')
    isSortingVariables: ko.observable(no)
    showAttributeVars: ko.observable(no)

    constructor: () ->
      @variables = pimatic.variables

      @variablesListViewRefresh = ko.computed( tc =>
        @variables()
        @enabledEditing()
        pimatic.try => $('#variables').listview('refresh').addClass("dark-background")
      ).extend(rateLimit: {timeout: 1, method: "notifyWhenChangesStop"})

      @lockButton = ko.computed( tc => 
        editing = @enabledEditing()
        return {
          icon: (if editing then 'check' else 'gear')
        }
      )

      @visibleVars = ko.computed( tc => 
        return ko.utils.arrayFilter(@variables(), (item) =>
          return @showAttributeVars() or (not item.isDeviceAttribute())
        )
      )

      @toggleEditingText = ko.computed( tc => 
        unless @enabledEditing() 
          __('Edit lists')
        else
          __('Lock lists')
      )

      @showAttributeVarsText = ko.computed( tc => 
        unless @showAttributeVars() 
          __('Show device attribute variables')
        else
          __('Hide device attribute variables')
      )



    afterRenderVariable: (elements) ->
      #handleHTML = $('#sortable-handle-template').text()
      #$(elements).find("a").before($(handleHTML))

    toggleEditing: ->
      @enabledEditing(not @enabledEditing())
      pimatic.loading "enableediting", "show", text: __('Saving')
      $.ajax("/enabledEditing/#{@enabledEditing()}",
        global: false # don't show loading indicator
      ).always( ->
        pimatic.loading "enableediting", "hide"
      ).done(ajaxShowToast)

    onVariablesSorted: ->
      order = (variable.name for variable in @variables())
      pimatic.loading "variableorder", "show", text: __('Saving')
      $.ajax("update-variable-order",
        type: "POST"
        global: false
        data: {order: order}
      ).always( ->
        pimatic.loading "variableorder", "hide"
      ).done(ajaxShowToast).fail(ajaxAlertFail)

    onDropVariableOnTrash: (variable) ->
      really = confirm(__("Do you really want to delete variable: %s?", '$' + variable.name))
      if really then (doDeletion = =>
        pimatic.loading "deletevariable", "show", text: __('Saving')
        $.get("/api/variable/#{variable.name}/remove").done( (data) =>
          if data.success
            @variables.remove(variable)
        ).always( => 
          pimatic.loading "deletevariable", "hide"
        ).done(ajaxShowToast).fail(ajaxAlertFail)
      )() 

    onAddVariableClicked: ->
      editVariablePage = pimatic.pages.editVariable
      editVariablePage.resetFields()
      editVariablePage.action('add')
      return true

    onEditVariableClicked: (variable)->
      unless variable.isDeviceAttribute()
        editVariablePage = pimatic.pages.editVariable
        editVariablePage.variableName(variable.name)
        editVariablePage.variableValue(
          if variable.type() is 'value' then variable.value() else variable.exprInputStr()
        )
        editVariablePage.variableType(variable.type())
        editVariablePage.action('update')
        return true
      else return false

    toggleShowAttributeVars: () ->
      @showAttributeVars(not @showAttributeVars())
      pimatic.loading "showAttributeVars", "show", text: __('Saving')
      $.ajax("/showAttributeVars/#{@showAttributeVars()}",
        global: false # don't show loading indicator
      ).always( ->
        pimatic.loading "showAttributeVars", "hide"
      ).done(ajaxShowToast)


  pimatic.pages.variables = variablePage = new VariablesViewModel()

)

$(document).on("pagecreate", '#variables-page', tc (event) ->

  variablesPage = pimatic.pages.variables
  try
    ko.applyBindings(variablesPage, $('#variables-page')[0])
  catch e
    TraceKit.report(e)
    pimatic.storage?.removeAll()
    window.location.reload()

  $("#variables .handle").disableSelection()
  return
)

$(document).on("pagebeforeshow", '#variables-page', tc (event) ->
  pimatic.try => $('#variables').listview('refresh').addClass("dark-background")
)


