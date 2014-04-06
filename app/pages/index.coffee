# index-page
# ----------

$(document).on( "pagebeforecreate", (event) ->
  # Just execute it one time
  if pimatic.pages.index? then return
  ###
    Rule class that are shown in the Rules List
  ###

  handleHTML = $('#sortable-handle-template').text()

  class Rule
    @mapping = {
      key: (data) => data.id
      copy: ['id']
    }
    constructor: (data) ->
      ko.mapping.fromJS(data, @constructor.mapping, this)
    update: (data) ->
      ko.mapping.fromJS(data, @constructor.mapping, this)
    afterRender: (elements) ->
      $(elements).find("a").before($(handleHTML))

  class Variable
    @mapping = {
      key: (data) => data.name
      observe: ['value', 'type', 'exprInputStr', 'exprTokens']
    }
    constructor: (data) ->
      unless data.value? then data.value = null
      unless data.exprInputStr? then data.exprInputStr = null
      unless data.exprTokens? then data.exprTokens = null
      ko.mapping.fromJS(data, @constructor.mapping, this)

      @displayName = ko.computed( => "$#{@name}" )
      @hasValue = ko.computed( => @value()? )
      @displayValue = ko.computed( => if @hasValue() then @value() else "null" )
    isDeviceAttribute: -> $.inArray('.', @name) isnt -1
    update: (data) ->
      ko.mapping.fromJS(data, @constructor.mapping, this)
    afterRender: (elements) ->
      $(elements).find("a").before($(handleHTML))

  # Export the rule class
  pimatic.Rule = Rule
  pimatic.Variable = Variable

  class IndexViewModel
    # static property:
    @mapping = {
      items:
        create: ({data, parent, skip}) =>
          itemClass = pimatic.templateClasses[data.template]
          unless itemClass?
            console.warn "Could not find a template class for #{data.template}"
            itemClass = pimatic.Item
          item = new itemClass(data)
          return item
        update: ({data, parent, target}) =>
          target.update(data)
          return target
        key: (data) => data.itemId
      rules:
        create: ({data, parent, skip}) => new pimatic.Rule(data)
        update: ({data, parent, target}) =>
          target.update(data)
          return target
        key: (data) => data.id
      variables:
        create: ({data, parent, skip}) => new pimatic.Variable(data)
        update: ({data, parent, target}) =>
          target.update(data)
          return target
        key: (data) => data.name
    }

    loading: no
    pageCreated: ko.observable(no)
    items: ko.observableArray([])
    rules: ko.observableArray([])
    variables: ko.observableArray([])
    errorCount: ko.observable(0)
    enabledEditing: ko.observable(no)
    hasRootCACert: ko.observable(no)
    rememberme: ko.observable(no)
    showAttributeVars: ko.observable(no)
    ruleItemCssClass: ko.observable('')

    isSortingItems: ko.observable(no)
    isSortingRules: ko.observable(no)
    isSortingVariables: ko.observable(no)

    constructor: () ->
      @setupStorage()

      @lockButton = ko.computed( => 
        editing = @enabledEditing()
        return {
          icon: (if editing then 'check' else 'gear')
        }
      )

      @visibleVars = ko.computed( => 
        return ko.utils.arrayFilter(@variables(), (item) =>
          return @showAttributeVars() or (not item.isDeviceAttribute())
        )
      )

      @itemsListViewRefresh = ko.computed( =>
        @items()
        @isSortingItems()
        @enabledEditing()
        if @pageCreated()  
          try
            $('#items').listview('refresh')
          catch e
            #ignore error refreshing
        return ''
      ).extend(rateLimit: {timeout: 0, method: "notifyWhenChangesStop"})

      @rulesListViewRefresh = ko.computed( =>
        @rules()
        @isSortingRules()
        @enabledEditing()
        if @pageCreated()  
          try
            $('#rules').listview('refresh')
          catch e
            #ignore error refreshing
        return ''
      ).extend(rateLimit: {timeout: 0, method: "notifyWhenChangesStop"})

      @variablesListViewRefresh = ko.computed( =>
        @variables()
        @enabledEditing()
        @showAttributeVars()
        if @pageCreated()  
          try
            $('#variables').listview('refresh')
          catch e
            #ignore error refreshing
        return ''
      ).extend(rateLimit: {timeout: 0, method: "notifyWhenChangesStop"})

      if pimatic.storage.isSet('pimatic.indexPage')
        data = pimatic.storage.get('pimatic.indexPage')
        @updateFromJs(data)

      @autosave = ko.computed( =>
        data = ko.mapping.toJS(this)
        pimatic.storage.set('pimatic.indexPage', data)
      ).extend(rateLimit: {timeout: 500, method: "notifyWhenChangesStop"})

      sendToServer = yes
      @rememberme.subscribe( (shouldRememberMe) =>
        if sendToServer
          $.get("remember", rememberMe: shouldRememberMe)
            .done(ajaxShowToast)
            .fail( => 
              sendToServer = no
              @rememberme(not shouldRememberMe)
            ).fail(ajaxAlertFail)
        else 
          sendToServer = yes
        # swap storage
        allData = pimatic.storage.get('pimatic')
        pimatic.storage.removeAll()
        if shouldRememberMe
          pimatic.storage = $.localStorage
        else
          pimatic.storage = $.sessionStorage
        pimatic.storage.set('pimatic', allData)
      )

      @toggleEditingText = ko.computed( => 
        unless @enabledEditing() 
          __('Edit lists')
        else
          __('Lock lists')
      )

      @showAttributeVarsText = ko.computed( => 
        unless @showAttributeVars() 
          __('Show device attribute variables')
        else
          __('Hide device attribute variables')
      )

    setupStorage: ->
      if $.localStorage.isSet('pimatic')
        # Select localStorage
        pimatic.storage = $.localStorage
        $.sessionStorage.removeAll()
        @rememberme(yes)
      else if $.sessionStorage.isSet('pimatic')
        # Select sessionSotrage
        pimatic.storage = $.sessionStorage
        $.localStorage.removeAll()
        @rememberme(no)
      else
        # select sessionStorage as default
        pimatic.storage = $.sessionStorage
        @rememberme(no)
        pimatic.storage.set('pimatic', {})


    updateFromJs: (data) -> 
      ko.mapping.fromJS(data, IndexViewModel.mapping, this)

    getItemTemplate: (item) ->
      template = (
        if item.type is 'device'
          if item.template? then "#{item.template}-template"
          else "devie-template"
        else if item.type is 'variable' then 'variable-item-template'
        else "#{item.type}-template"
      )
      if $('#'+template).length > 0 then return template
      else return 'device-template'

    afterRenderItem: (elements, item) ->
      item.afterRender(elements)

    afterRenderRule: (elements, rule) ->
      rule.afterRender(elements)

    afterRenderVariable: (elements, variable) ->
      variable.afterRender(elements)

    addItemFromJs: (data) ->
      item = IndexViewModel.mapping.items.create({data})
      @items.push(item)

    addVariableFromJs: (data) ->
      variable = IndexViewModel.mapping.variables.create({data})
      @variables.push(variable)

    toggleShowAttributeVars: () ->
      @showAttributeVars(not @showAttributeVars())
      pimatic.loading "showAttributeVars", "show", text: __('Saving')
      $.ajax("/showAttributeVars/#{@showAttributeVars()}",
        global: false # don't show loading indicator
      ).always( ->
        pimatic.loading "showAttributeVars", "hide"
      ).done(ajaxShowToast)

    removeItem: (itemId) ->
      @items.remove( (item) => item.itemId is itemId )

    removeRule: (ruleId) ->
      @rules.remove( (rule) => rule.id is ruleId )

    removeVariable: (varName) ->
      @variables.remove( (variable) => variable.name is varName )

    updateRuleFromJs: (data) ->
      rule = ko.utils.arrayFirst(@rules(), (rule) => rule.id is data.id )
      unless rule?
        rule = IndexViewModel.mapping.rules.create({data})
        @rules.push(rule)
      else 
        rule.update(data)

    updateItemOrder: (order) ->
      toIndex = (id) -> 
        index = $.inArray(id, order)
        if index is -1 # if not in array then move it to the back
          index = 999999
        return index
      @items.sort( (left, right) => toIndex(left.itemId) - toIndex(right.itemId) )

    updateRuleOrder: (order) ->
      toIndex = (id) -> 
        index = $.inArray(id, order)
        if index is -1 # if not in array then move it to the back
          index = 999999
        return index
      @rules.sort( (left, right) => toIndex(left.id) - toIndex(right.id) )

    updateVariableOrder: (order) ->
      toIndex = (name) -> 
        index = $.inArray(name, order)
        if index is -1 # if not in array then move it to the back
          index = 999999
        return index
      @variables.sort( (left, right) => toIndex(left.name) - toIndex(right.name) )

    updateDeviceAttribute: (deviceId, attrName, attrValue) ->
      for item in @items()
        if item.type is 'device' and item.deviceId is deviceId
          item.updateAttribute(attrName, attrValue)
          break

    updateVariable: (varInfo) ->
      for variable in @variables()
        if variable.name is varInfo.name
          variable.value(varInfo.value) if varInfo.value?
          variable.type(varInfo.type) if varInfo.type?
          variable.exprInputStr(varInfo.exprInputStr) if varInfo.exprInputStr?
      for item in @items()
        if item.type is "variable" and item.name is varInfo.name
          item.value(varInfo.value)

    toggleEditing: ->
      @enabledEditing(not @enabledEditing())
      pimatic.loading "enableediting", "show", text: __('Saving')
      $.ajax("/enabledEditing/#{@enabledEditing()}",
        global: false # don't show loading indicator
      ).always( ->
        pimatic.loading "enableediting", "hide"
      ).done(ajaxShowToast)

    onItemsSorted: ->
      order = (item.itemId for item in @items())
      pimatic.loading "itemorder", "show", text: __('Saving')
      $.ajax("update-item-order", 
        type: "POST"
        global: false
        data: {order: order}
      ).always( ->
        pimatic.loading "itemorder", "hide"
      ).done(ajaxShowToast)
      .fail(ajaxAlertFail)

    onRulesSorted: ->
      order = (rule.id for rule in @rules())
      pimatic.loading "ruleorder", "show", text: __('Saving')
      $.ajax("update-rule-order",
        type: "POST"
        global: false
        data: {order: order}
      ).always( ->
        pimatic.loading "ruleorder", "hide"
      ).done(ajaxShowToast).fail(ajaxAlertFail)

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

    onDropItemOnTrash: (item) ->
      pimatic.loading "deleteitem", "show", text: __('Saving')
      $.post('remove-item', itemId: item.itemId).done( (data) =>
        if data.success
          @items.remove(item)
      ).always( => 
        pimatic.loading "deleteitem", "hide"
      ).done(ajaxShowToast).fail(ajaxAlertFail)

    onAddRuleClicked: ->
      editRulePage = pimatic.pages.editRule
      editRulePage.resetFields()
      editRulePage.action('add')
      editRulePage.ruleEnabled(yes)
      return true

    onEditRuleClicked: (rule)->
      editRulePage = pimatic.pages.editRule
      editRulePage.action('update')
      editRulePage.ruleId(rule.id)
      editRulePage.ruleName(rule.name())
      editRulePage.ruleCondition(rule.condition())
      editRulePage.ruleActions(rule.action())
      editRulePage.ruleEnabled(rule.active())
      return true

    onAddVariableClicked: ->
      editVariablePage = pimatic.pages.editVariable
      editVariablePage.resetFields()
      editVariablePage.action('add')
      return true

    onEditVariableClicked: (variable)->
      unless variable.isDeviceAttribute()
        editVariablePage = pimatic.pages.editVariable
        editVariablePage.variableName(variable.name)
        editVariablePage.variableValue(variable.value())
        editVariablePage.variableType(variable.type())
        editVariablePage.action('update')
        return true
      else return false

    toLoginPage: ->
      urlEncoded = encodeURIComponent(window.location.href)
      window.location.href = "/login?url=#{urlEncoded}"


  pimatic.pages.index = indexPage = new IndexViewModel()

  pimatic.socket.on("welcome", (data) ->
    indexPage.updateFromJs(data)
  )

  pimatic.socket.on("device-attribute", (attrEvent) -> 
    indexPage.updateDeviceAttribute(attrEvent.id, attrEvent.name, attrEvent.value)
  )

  pimatic.socket.on("variable", (variable) -> indexPage.updateVariable(variable))

  pimatic.socket.on("item-add", (item) -> indexPage.addItemFromJs(item))
  pimatic.socket.on("item-remove", (itemId) -> indexPage.removeItem(itemId))
  pimatic.socket.on("item-order", (order) -> indexPage.updateItemOrder(order))

  pimatic.socket.on("rule-add", (rule) -> indexPage.updateRuleFromJs(rule))
  pimatic.socket.on("rule-update", (rule) -> indexPage.updateRuleFromJs(rule))
  pimatic.socket.on("rule-remove", (ruleId) -> indexPage.removeRule(ruleId))
  pimatic.socket.on("rule-order", (order) -> indexPage.updateRuleOrder(order))

  pimatic.socket.on("variable-add", (variable) -> indexPage.addVariableFromJs(variable))
  pimatic.socket.on("variable-remove", (variableName) -> indexPage.removeVariable(variableName))
  pimatic.socket.on("variable-order", (order) -> indexPage.updateVariableOrder(order))

  pimatic.socket.on('log', (entry) -> 
    if entry.level is "error" then indexPage.errorCount(indexPage.errorCount() + 1)
  )
  return
)

$(document).on("pagecreate", '#index', (event) ->
  indexPage = pimatic.pages.index
  ko.applyBindings(indexPage, $('#index')[0])

  $('#index #items').on("change", ".switch", (event) ->
    switchDevice = ko.dataFor(this)
    switchDevice.onSwitchChange()
    return
  )

  $('#index #items').on("slidestop", ".dimmer", (event) ->
    dimmerDevice = ko.dataFor(this)
    dimmerDevice.onSliderStop()
    return
  )

  $('#index #items').on("vclick", ".shutter-down", (event) ->
    shutterDevice = ko.dataFor(this)
    shutterDevice.onShutterDownClicked()
    return false
  )

  $('#index #items').on("vclick", ".shutter-up", (event) ->
    shutterDevice = ko.dataFor(this)
    shutterDevice.onShutterUpClicked()
    return false
  )

  # $('#index #items').on("click", ".device-label", (event, ui) ->
  #   deviceId = $(this).parents(".item").data('item-id')
  #   device = pimatic.devices[deviceId]
  #   unless device? then return
  #   div = $ "#device-info-popup"
  #   div.find('.info-id .info-val').text device.id
  #   div.find('.info-name .info-val').text device.name
  #   div.find(".info-attr").remove()
  #   for attrName, attr of device.attributes
  #     attr = $('<li class="info-attr">').text(attr.label)
  #     div.find("ul").append attr
  #   div.find('ul').listview('refresh')
  #   div.popup "open"
  #   return
  # )

  $("#items .handle, #rules .handle").disableSelection()
  indexPage.pageCreated(yes)

  return
)






