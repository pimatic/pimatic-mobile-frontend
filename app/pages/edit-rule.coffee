# edit-rule-page
# --------------

merge = Array.prototype.concat
LazyLoad.js(merge.apply(scripts.textcomplete))

$(document).on("pagecreate", '#edit-rule-page' , (event) ->
  if pimatic.pages.editRule? then return


  class ConditionInput

    visible: ko.observable(false)
    presets: ko.observable([])
    elements: ko.observable([])
    forElements: ko.observable([])
    presetsVisible: ko.observable(true)
    elementsVisible: ko.observable(true)
    forElementsVisible: ko.observable(true)
    forEnabled: ko.observable(false)
    parentOp: null
    side: "left"
    errors: ko.observable(true)
    inputValue: ko.observable(true)
    disablePredicateInput: ko.observable(false)
    disableElementsInput: ko.observable(false)
    justTrigger: ko.observable(false)
    canRemove: ko.observable(false)

    constructor: (@ruleView) ->

      @computedPredicateToken = ko.computed( =>
        tokens = ""
        if @justTrigger()
          tokens +="trigger: "
        for e in @elements()
          tokens += e.match()
        return tokens
      )

      @computedToken = ko.computed( =>
        tokens = @computedPredicateToken()
        if @forEnabled()
          for e in @forElements()
            tokens += e.match()
        return tokens
      )

      @computedToken.subscribe(@setInputValue)
      @inputValue.subscribe( (value) =>
        unless @dontUpdate
          @disableElementsInput(true)
          clearTimeout(@_getElments)
          @_getElments = setTimeout( (=> @getElements value, null, "input changed"), 2000)
      )


    setInputValue: (value) =>
      @dontUpdate = yes
      @inputValue(value)
      @dontUpdate = no      

    keypress: (model, event) =>
      if event.keyCode is 13 #enter
        @parse(@inputValue(), true)
        return false
      return true

    parse: (value)->
      pimatic.client.rest.getRuleConditionHints(
        {conditionInput: value}
      ).done( (data) =>
        if data.success and data.hints.tree?
          data.hints.tree.parent = @parentOp
          @updateTree(data.hints.tree)
          @visible(false)
        else
          @errors(data.hints.errors)
          swal("Oops...", __(data.hints.errors[0]), "error")
      )

    refreshPresets: ->
      pimatic.client.rest.getPredicatePresets(
        {}
      ).done( (data) =>
        if data.success and data.presets?
          @presets(data.presets)
      )


    updateTree: (ele) ->
      unless @parentOp?
        @ruleView.tree(ele)
      else
        unless @side then throw new Error("illegal side: ", @side)
        @parentOp[@side] = ele
        @ruleView.tree.valueHasMutated()

    selectPredicate: (pred) =>
      @setInputValue(pred.input)
      @getElements(pred.input, pred.predicateProviderClass, "selectPredicate")

    getElements: (input, predicateProviderClass, source) =>
      if @inputValue().length is 0
        @showDefaultSelection()
      else
        @disableElementsInput(true)
        @disablePredicateInput(true)
        pimatic.client.rest.getPredicateInfo(
          {input, predicateProviderClass}
        ).done( (data) =>
          if data.success
            if data.result.predicate?
              @justTrigger(data.result.predicate.justTrigger)
              elements = data.result.elements
              # If we are showing a new predicate and we were not able to parse it
              # then add just a single text element, so that the user can correct the predicate
              if @elements().length is 0 and not (elements?)
                elements = [{match: data.result.predicate.token, type: "text"}]
              # if there are no errors update the elements
              if data.result.errors.length is 0 and elements?
                @showElementSelection(
                  elements, 
                  data.result.forElements, 
                  data.result.predicate?.for?
                )
            @errors(data.result.errors or [])
        ).always( =>
          @disableElementsInput(false)
          @disablePredicateInput(false)
        )

    showDefaultSelection: =>
      @presetsVisible(true)
      @elementsVisible(false)
      @forElementsVisible(false)
      @refreshPresets() if @presets().length is 0
      @disableElementsInput(false)
      @disablePredicateInput(false)

    showElementSelection: (elements, forElements, forEnabled) ->
      @presetsVisible(false)
      @elementsVisible(true)
      @forEnabled(forEnabled)

      prepareElements = (elements) ->
        for e in elements
          unless ko.isObservable e.match
            if e.wildcardMatch and e.type isnt "text"
              e.match = ko.observable(e.wildcard)
            else 
              e.match = ko.observable(e.match)  
        return elements

      # cancle subscribes
      if @eleSubscriptions?
        es.dispose() for es in @eleSubscriptions
      @eleSubscriptions = []

      prepareElements elements
      # listen for changes
      isUpdating = false
      for e, i in elements
        do (i, e) =>
          @eleSubscriptions.push e.match.subscribe( (value) =>
            if isUpdating then return
            isUpdating = true
            elements = @elements()
            j = i+1
            while j < elements.length
              element = elements[j]
              if element.wildcard?
                if element.options?
                  unless element.wildcard in element.options
                    element.options.unshift element.wildcard
                element.match(element.wildcard)
              j++
            isUpdating = false
            clearTimeout(@_getElments)
            timeout = if elements[i].type is "select" then 100 else 2000
            @_getElments = setTimeout( (=> @getElements @computedToken(), null, "element changed"), timeout)
          )
      @elements(elements)
      if forElements?
        @forElements(prepareElements forElements)
      else
        @forElements([])
      @forElementsVisible(forElements?)

    showEmpty: (parentOp) ->
      @side = "right"
      @parentOp = parentOp
      @visible(true)
      @setInputValue("")
      @refreshPresets()
      @showDefaultSelection()
      @justTrigger(false)
      @canRemove(false)
      supportsTouch = 'ontouchstart' of window or navigator.msMaxTouchPoints
      unless supportsTouch
        $('#rule-condition-input').focus()

    editPredicate: (node) ->
      @side = (
        if node.parent?.left is node then "left"
        else "right"
      )
      @parentOp = node.parent
      @visible(true)
      @canRemove(true)

      @setInputValue(@ruleView.predicateToString(node.predicate))
      @getElements(@inputValue())

    ok: =>
      @parse(@inputValue(), true)

    cancel: =>
      if @parentOp? 
        if @parentOp[@side] is null
          if @parentOp.parent?
            if @side is "left"
              if @parentOp.parent.left is @parentOp
                @parentOp.parent.left = @parentOp.right
                @parentOp.parent.left.parent = @parentOp.parent
              else if @parentOp.parent.right is @parentOp
                @parentOp.parent.right = @parentOp.right
                @parentOp.parent.right.parent = @parentOp.parent
            else
              if @parentOp.parent.left is @parentOp
                @parentOp.parent.left = @parentOp.left
                @parentOp.parent.left.parent = @parentOp.parent
              else if @parentOp.parent.right is @parentOp
                @parentOp.parent.right = @parentOp.left
                @parentOp.parent.right.parent = @parentOp.parent
            @ruleView.tree.valueHasMutated()
          else
            if @side is "left"
              @parentOp.right.parent = undefined
              @ruleView.tree(@parentOp.right)
            else
              @parentOp.left.parent = undefined
              @ruleView.tree(@parentOp.left)

      
      @visible(false)

    remove: =>
      if @parentOp?
        if @parentOp.parent?
          if @side is "left"
            if @parentOp.parent.left is @parentOp
              @parentOp.parent.left = @parentOp.right
              @parentOp.parent.left.parent = @parentOp.parent
            else if @parentOp.parent.right is @parentOp
              @parentOp.parent.right = @parentOp.right
              @parentOp.parent.right.parent = @parentOp.parent
          else
            if @parentOp.parent.left is @parentOp
              @parentOp.parent.left = @parentOp.left
              @parentOp.parent.left.parent = @parentOp.parent
            else if @parentOp.parent.right is @parentOp
              @parentOp.parent.right = @parentOp.left
              @parentOp.parent.right.parent = @parentOp.parent
        else
          if @side is "left"
            @parentOp.right.parent = undefined
            @ruleView.tree(@parentOp.right)
          else
            @parentOp.left.parent = undefined
            @ruleView.tree(@parentOp.left)
        @ruleView.tree.valueHasMutated()
      else
        @ruleView.tree(null)

      @visible(false)

    elementOptionsText: (option) => option.replace(/^\{(.*)\}$/, 'Choose $1...')

  class EditRuleViewModel

    autocompleteAjax: null
    autocompleEnabled: yes

    action: ko.observable('add')
    ruleId: ko.observable('')
    ruleName: ko.observable('')
    ruleCondition: ko.observable('')
    ruleActions: ko.observable('')
    ruleEnabled: ko.observable(yes)
    ruleLogging: ko.observable(yes)
    tree: ko.observable(null)
    editMode: ko.observable("text")

    constructor: ->
      @ruleAsText = ko.computed( => 
        if @editMode() is "text" then "when #{@ruleCondition()} then #{@ruleActions()}"
        else "when #{@getTreeAsString()} then #{@ruleActions()}"
      )
      @pageTitle = ko.computed( => 
        return (if @action() is 'add' then __('Add new rule') else __('Edit rule'))
      )

      pimatic.autoFillId(@ruleName, @ruleId, @action)
      @conditionInput = new ConditionInput(this)

    resetFields: () ->
      @ruleId('')
      @ruleName('')
      @ruleCondition('')
      @ruleActions('')
      @ruleEnabled(yes)
      @ruleLogging(yes)

    addCondition: =>
      @conditionInput.showEmpty(null)

    editPredicate: (ele) =>
      @conditionInput.editPredicate(ele)

    addAnd: (ele) => @addBinaryOp('and', ele)
    addAndIf: (ele) => @addBinaryOp('and if', ele)

    addOr: (ele) =>  @addBinaryOp('or', ele)
    addOrWhen: (ele) =>  @addBinaryOp('or when', ele)

    addBinaryOp: (type, ele) ->
      newBinOp =  {type, left: ele, right: null}
      if ele.parent?
        if ele.parent.left is ele
          ele.parent.left = newBinOp
        else
          ele.parent.right = newBinOp
        newBinOp.parent = ele.parent
        ele.parent = newBinOp
        @tree.valueHasMutated()
      else
        ele.parent = newBinOp
        @tree(newBinOp)

      @conditionInput.showEmpty(newBinOp)

    onSubmit: ->
      unless pimatic.isValidId(@ruleId())
        alert __(pimatic.invalidIdMessage)
        return

      params = {
        ruleId: @ruleId()
        rule:
          ruleString: @ruleAsText()
          active: @ruleEnabled()
          name: @ruleName()
          logging: @ruleLogging()
      }
      
      (
        switch @action()
          when 'add' then pimatic.client.rest.addRuleByString(params)
          when 'update' then pimatic.client.rest.updateRuleByString(params)
          else throw new Error("Illegal rule action: #{@action()}")
      ).done( (data) ->
          if data.success then $.mobile.changePage '#rules-page', {transition: 'slide', reverse: true}   
          else alert data.error
      ).fail(ajaxAlertFail)
      return false

    onRemove: ->
      really = confirm(__("Do you really want to delete the %s rule?", @ruleName()))
      if really
        pimatic.client.rest.removeRule({ruleId: @ruleId()})
          .done( (data) ->
            if data.success then $.mobile.changePage '#rules-page', {transition: 'slide', reverse: true}   
            else alert data.error
          ).fail(ajaxAlertFail)
      return false

    onCopy: ->
      ruleId = @ruleId()
      ruleName = @ruleName()
      @action('add')

      if (match = ruleName.match(/.*?([0-9]+)$/))?
        num = match[1]
        @ruleName(ruleName.substring(0, ruleName.length-num.length-1) + (parseInt(num,10)+1))
      else
        @ruleName(ruleName + " 2")

      if (match = ruleId.match(/.*?([0-9]+)$/))?
        num = match[1]
        @ruleId(ruleId.substring(0, ruleId.length-num.length-1) + (parseInt(num,10)+1))
      else
        @ruleId(ruleId + "-2")

    predicateToString: (predicate) ->
      if predicate.justTrigger
        inputValue = "trigger: "
      else
        inputValue = ""
      inputValue += predicate.token
      if predicate.for?
        inputValue += " for #{predicate.for.token}"
      return inputValue

    getTreeAsString: ->
      tree = @tree()
      unless tree? then return ""
      nodeToString = (node, parent) =>
        unless node? then return ""
        switch node.type
          when 'predicate'
            @predicateToString(node.predicate)
          else 
            sub = "#{nodeToString node.left, node} #{node.type} #{nodeToString node.right, node}"
            wrap = parent? and (parent.type isnt node.type) and
              not (parent.type in ['and if', 'or when'])
            if wrap then "[#{sub}]" else sub

      return nodeToString tree

    setTextMode: =>
      @ruleCondition(@getTreeAsString())
      @editMode('text')
      @saveEditMode('text')

    setGuiMode: =>

      enhanceTree = (node, parent) ->
        node.parent = parent
        enhanceTree(node.left, node) if node.left?
        enhanceTree(node.right, node) if node.right?
        return node 

      pimatic.client.rest.getRuleConditionHints(
        {conditionInput: @ruleCondition()},
        {global: yes}
      ).done( (data) =>
        if data.success
          if data.hints.errors.length is 0
            if data.hints.tree?
              @tree(enhanceTree data.hints.tree)
            else
              @tree(null)
            @editMode('gui')
            @saveEditMode('gui')
          else
            swal("Oops...", __(data.hints.errors[0]), "error")
      ).fail(ajaxAlertFail)

    saveEditMode: (mode) =>
      data = pimatic.storage.get('pimatic.editRule') or {}
      data.editMode = mode
      pimatic.storage.set('pimatic.editRule', data)

  try
    pimatic.pages.editRule = new EditRuleViewModel()
  catch e
    TraceKit.report(e)
  return
)

$(document).on("pagecreate", '#edit-rule-page', (event) ->
  try
    ko.applyBindings(pimatic.pages.editRule, $('#edit-rule-page')[0])

    customReplace = (pre, value) -> 
      commonPart = this.ac.getCommonPart(pre, value)
      return pre.substring(0, pre.length - commonPart.length) + value

    customTemplate = (value) ->
      commonPart = this.ac.getCommonPart(@lastTerm, value)
      remainder = value.substring(commonPart.length, value.length)
      return "<strong>#{commonPart}</strong>#{remainder}"

    editRulePage = pimatic.pages.editRule

    # https://github.com/yuku-t/jquery-textcomplete
    $("#edit-rule-condition").textcomplete([
      match: /^(.*)$/
      search: (term, callback) ->
        editRulePage.autocompleteAjax?.abort()
        result = {autocomplete: [], format: []}
        if pimatic.pages.editRule.autocompleEnabled
          editRulePage.autocompleteAjax = pimatic.client.rest.getRuleConditionHints(
            {conditionInput: term},
            {global: false}
          ).done( (data) =>
            result.autocomplete = data.hints?.autocomplete or []
            result.format = data.hints?.format or []
            if data.error then console.log data.error
            @lastTerm = term
            callback result
          ).fail( => callback result )
        else callback result
      index: 1
      replace: (pre, value) ->
        textValue = customReplace.call(this, pre, value)
        editRulePage.ruleCondition(textValue)
        return textValue
      change: (text) -> editRulePage.ruleCondition(text)
      template: customTemplate
    ])

    $("#edit-rule-actions").textcomplete([
      match: /^(.*)$/
      search: (term, callback) ->
        result = {autocomplete: [], format: []}
        if pimatic.pages.editRule.autocompleEnabled
          editRulePage.autocompleteAjax?.abort()
          editRulePage.autocompleteAjax = pimatic.client.rest.getRuleActionsHints(
            {actionsInput: term},
            {global: false}
          ).done( (data) =>
            result.autocomplete = data.hints?.autocomplete or []
            result.format = data.hints?.format or []
            if data.message? and data.message.length > 0
              pimatic.showToast data.message[0]
            if data.error then console.log data.error
            @lastTerm = term
            callback result
          ).fail( => callback result )
        else callback result
      index: 1
      replace: (pre, value) ->
        textValue = customReplace.call(this, pre, value)
        editRulePage.ruleActions(textValue)
        return textValue
      change: (text) -> editRulePage.ruleActions(text)
      template: customTemplate
    ])
  catch e
    TraceKit.report(e)
)

$(document).on("pagebeforehide", '#edit-rule-page', (event) ->
  try
    pimatic.pages.editRule.autocompleteAjax?.abort()
  catch e
    TraceKit.report(e)
)

$(document).on("pagebeforeshow", '#edit-rule-page', (event) ->
  data = pimatic.storage.get('pimatic.editRule') or {}
  editRule = pimatic.pages.editRule
  params = jQuery.mobile.pageParams
  jQuery.mobile.pageParams = {}
  if params?
    data.params = {
      action: params.action
      ruleId: params.rule?.id
    }
    pimatic.storage.set('pimatic.editRule', data)
  else
    if data.params?
      params = {
        action: data.params.action
        rule: pimatic.getRuleById(data.params.ruleId)
      }
      unless params.rule?
        params.action = 'add'
  if params?.action is "update"
    rule = params.rule
    editRule.action('update')
    editRule.ruleId(rule.id)
    editRule.ruleName(rule.name())
    editRule.ruleCondition(rule.conditionToken())
    editRule.ruleActions(rule.actionsToken())
    editRule.ruleEnabled(rule.active())
    editRule.ruleLogging(rule.logging())
  else
    editRule.resetFields()
    editRule.action('add')
    editRule.ruleEnabled(yes)

  
  mode = data.editMode or 'gui'
  switch mode
    when 'gui' then editRule.setGuiMode()
    when 'text'
      editRule.editMode('text')
  return
)
