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
      observe: ['value']
    }
    constructor: (data) ->
      unless data.value? then data.value = null
      ko.mapping.fromJS(data, @constructor.mapping, this)

      @displayName = ko.computed( => "$#{@name}" )
      @hasValue = ko.computed( => @value()? )
      @displayValue = ko.computed( => if @hasValue() then @value() else "null" )
    update: (data) ->
      ko.mapping.fromJS(data, @constructor.mapping, this)
    afterRender: (elements) ->
      $(elements).find("label").before($(handleHTML))

  # Export the rule class
  pimatic.Rule = Rule
  pimatic.Variable = Variable

  pimatic.templateClasses = {
    header: pimatic.HeaderItem
    button: pimatic.ButtonItem
    device: pimatic.DeviceItem  
    switch: pimatic.SwitchItem
    dimmer: pimatic.DimmerItem
    temperature: pimatic.TemperatureItem
    presence: pimatic.PresenceItem
  }

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
    hasData: no
    pageCreated: ko.observable(no)
    items: ko.observableArray([])
    rules: ko.observableArray([])
    variables: ko.observableArray([])
    errorCount: ko.observable(0)
    enabledEditing: ko.observable(no)
    hasRootCACert: ko.observable(no)
    rememberme: ko.observable(no)
    showAttributeVars: ko.observable(no)

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
          pimatic.storage = $.sessionStorage
        else
          pimatic.storage = $.localStorage
        pimatic.storage.set('pimatic', allData)
      )

      @showAttributeVarsText = ko.computed( => __('show device attribute variables'))

    setupStorage: ->
      if $.localStorage.isSet('pimatic')
        # Select localStorage
        pimatic.storage = $.localStorage
        $.sessionStorage.removeAll()
        @rememberme(no)
      else if $.sessionStorage.isSet('pimatic')
        # Select sessionSotrage
        pimatic.storage = $.sessionStorage
        $.localStorage.removeAll()
        @rememberme(yes)
      else
        # select localStorage as default
        pimatic.storage = $.localStorage
        @rememberme(no)
        pimatic.storage.set('pimatic', {})


    updateFromJs: (data) -> 
      ko.mapping.fromJS(data, IndexViewModel.mapping, this)

    getItemTemplate: (item) ->
      template = (
        if item.type is 'device'
          if item.template? then "#{item.template}-template"
          else "devie-template"
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

    toggleShowAttributeVars: () ->
      @showAttributeVars(not @showAttributeVars())

    removeItem: (itemId) ->
      @items.remove( (item) => item.itemId is itemId )

    removeRule: (ruleId) ->
      @rules.remove( (rule) => rule.id is ruleId )

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
      console.log order
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

    updateVariableValue: (varName, varValue) ->
      for variable in @variables()
        if variable.name is varName
          variable.value(varValue)

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
      console.log order
      pimatic.loading "variableorder", "show", text: __('Saving')
      $.ajax("update-variable-order",
        type: "POST"
        global: false
        data: {order: order}
      ).always( ->
        pimatic.loading "variableorder", "hide"
      ).done(ajaxShowToast).fail(ajaxAlertFail)

    onDropItemOnTrash: (ev, ui) ->
      item = ko.dataFor(ui.draggable[0])
      # Remove the item after sorting stopped:
      subscripton = @isSortingItems.subscribe( =>
        pimatic.loading "deleteitem", "show", text: __('Saving')
        $.post('remove-item', itemId: item.itemId).done( (data) =>
          if data.success
            if ui.helper.length > 0
              ui.helper.hide(0, => @items.remove(item) )
            else
              @items.remove(item)
        ).always( => 
          pimatic.loading "deleteitem", "hide"
        ).done(ajaxShowToast).fail(ajaxAlertFail)
        # Just do it once
        subscripton.dispose()
      )

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
      editRulePage.ruleCondition(rule.condition())
      editRulePage.ruleActions(rule.action())
      editRulePage.ruleEnabled(rule.active())
      return true

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

  pimatic.socket.on("variable", (varEvent) -> 
    indexPage.updateVariableValue(varEvent.name, varEvent.value)
  )

  pimatic.socket.on("item-add", (item) -> indexPage.addItemFromJs(item))
  pimatic.socket.on("item-remove", (itemId) -> indexPage.removeItem(itemId))
  pimatic.socket.on("item-order", (order) -> indexPage.updateItemOrder(order))

  pimatic.socket.on("rule-add", (rule) -> indexPage.updateRuleFromJs(rule))
  pimatic.socket.on("rule-update", (rule) -> indexPage.updateRuleFromJs(rule))
  pimatic.socket.on("rule-remove", (ruleId) -> indexPage.removeRule(ruleId))
  pimatic.socket.on("rule-order", (order) -> indexPage.updateRuleOrder(order))

  pimatic.socket.on("variable-order", (order) -> indexPage.updateVariableOrder(order))
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


fixScrollOverDraggableRule = ->
  _touchStart = $.ui.mouse.prototype._touchStart
  if _touchStart?
    $.ui.mouse.prototype._touchStart = (event) ->
      # Just alter behavior if the event is triggered on an draggable
      if this._isDragging?
        if this._isDragging is no
          # we are not dragging so allow scrolling
          return
      _touchStart.apply(this, [event]) 

    _touchMove = $.ui.mouse.prototype._touchMove
    $.ui.mouse.prototype._touchMove = (event) ->
      if this._isDragging?
        unless this._isDragging is yes
          # discard the event to not prevent defaults
          return
      _touchMove.apply(this, [event])

    _touchEnd = $.ui.mouse.prototype._touchEnd
    $.ui.mouse.prototype._touchEnd = (event) ->
      if this._isDragging?
        # stop dragging
        this._isDragging = no
        return
      _touchEnd.apply(this, [event]) 
fixScrollOverDraggableRule()






