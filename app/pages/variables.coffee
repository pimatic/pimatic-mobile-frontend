# index-page
# ----------
tc = pimatic.tryCatch

$(document).on( "pagebeforecreate", '#variables-page', tc (event) ->

  class VariablesViewModel

    enabledEditing: ko.observable(no)
    isSortingVariables: ko.observable(no)
    showAttributeVars: ko.observable(no)

    constructor: () ->
      @variables = pimatic.variables
      @groups = pimatic.groups

      @variablesListViewRefresh = ko.computed( tc =>
        @variables()
        @enabledEditing()
        g.variables() for g in @groups()
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

      @getUngroupedVariables =  ko.computed( tc =>
        ungroupedVariables = []
        groupedVariables = []
        for g in @groups()
          groupedVariables = groupedVariables.concat g.variables()
        for v in @variables()
          if v.isDeviceAttribute() then continue
          if ko.utils.arrayIndexOf(groupedVariables, v.name) is -1
            ungroupedVariables.push v
        return ungroupedVariables
      )

      @getDeviceAttributeVariables = ko.computed( tc =>
        return ( v for v in @variables() when v.isDeviceAttribute() )
      )

    afterRenderVariable: (elements) ->
      handleHTML = $('#sortable-handle-template').text()
      $(elements).find("a").before($(handleHTML))

    toggleEditing: ->
      @enabledEditing(not @enabledEditing())
      pimatic.loading "enableediting", "show", text: __('Saving')
      $.ajax("/enabledEditing/#{@enabledEditing()}",
        global: false # don't show loading indicator
      ).always( ->
        pimatic.loading "enableediting", "hide"
      ).done(ajaxShowToast)

    onVariablesSorted: (variable, eleBefore, eleAfter) =>

      addToGroup = (group, variableBefore) =>
        position = (
          unless variableBefore? then 0 
          else ko.utils.arrayIndexOf(group.variables(), variableBefore.name) + 1
        )
        if position is -1 then position = 0
        groupId = group.id

        pimatic.client.rest.addVariableToGroup({variableName: variable.name, groupId: groupId, position: position})
        .done(ajaxShowToast)
        .fail(ajaxAlertFail)

      removeFromGroup = ( (group) =>
        groupId = group.id
        pimatic.client.rest.removeVariableFromGroup({variableName: variable.name, groupId: groupId})
        .done(ajaxShowToast)
        .fail(ajaxAlertFail)
      )

      updateVariableOrder = ( (variableBefore) =>
        variableOrder = []
        unless variableBefore?
          variableOrder.push variable.name 
        for v in @variables()
          if v is variable then continue
          variableOrder.push(v.iname)
          if variableBefore? and v is variableBefore
            variableOrder.push(variable.name)
        pimatic.client.rest.updateVariableOrder({variableOrder})
        .done(ajaxShowToast)
        .fail(ajaxAlertFail)
      )

      updateGroupVariableOrder = ( (group, variableBefore) =>
        variablesOrder = []
        unless variableBefore?
          variablesOrder.push variable.name 
        for variableName in group.variables()
          if variableName is variable.name then continue
          variablesOrder.push(variableName)
          if variableBefore? and variableName is variableBefore.name
            variablesOrder.push(variable.name)
        pimatic.client.rest.updateGroup({groupId: group.id, group:{variablesOrder}})
        .done(ajaxShowToast)
        .fail(ajaxAlertFail)
      )
      
      if eleBefore?
        if eleBefore instanceof pimatic.Variable then g1 = eleBefore.group()
        else if eleBefore instanceof pimatic.Group then g1 = eleBefore
        else g1 = null
        variableBefore = (if eleBefore instanceof pimatic.Variable then eleBefore)
        g2 = variable.group()

        if g1 isnt g2
          if g1?
            addToGroup(g1, variableBefore)
          else if g2?
            removeFromGroup(g2)
          else
            updateVariableOrder(variableBefore)
        else
          if g1?
            updateGroupVariableOrder(g1, variableBefore)
          else
            updateVariableOrder(variableBefore)

    onDropVariableOnTrash: (variable) ->
      really = confirm(__("Do you really want to delete the variable %s?", variable.name))
      if really then (doDeletion = =>
          pimatic.loading "deletevariable", "show", text: __('Saving')
          pimatic.client.rest.removeVariable(name: variable.name).done( (data) =>
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


