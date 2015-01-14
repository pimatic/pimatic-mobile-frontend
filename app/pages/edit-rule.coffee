# edit-rule-page
# --------------

$(document).on("pagebeforecreate", (event) ->
  if pimatic.pages.editRule? then return


  class ConditionInput

    visible: ko.observable(false)
    value: ko.observable("")
    defaults: ko.observable([])
    elements: ko.observable([])
    parentOp: null

    constructor: (@ruleView) ->

    keypress: (model, event) =>
      if event.keyCode is 13 #enter
        @parse()
        return false
      return true

    parse: ->
      pimatic.client.rest.getRuleConditionHints(
        {conditionInput: @value()}
      ).done( (data) =>
        console.log data
        if data.success and data.hints.tree?
          data.hints.tree.parent = @parentOp
          @updateTree(data.hints.tree)
          @visible(false)
        else
          console.log "not valid"
      )

    refreshDefaults: ->
      pimatic.client.rest.getPredicateDefaults(
        {}
      ).done( (data) =>
        console.log data
        if data.success and data.defaults?
          @defaults(data.defaults)
      )


    updateTree: (ele) ->
      unless @parentOp?
        @ruleView.tree(ele)
      else
        @parentOp.right = ele
        @ruleView.tree(@ruleView.tree())

    selectPredicate: (pred) =>
      @value(pred.input)
      pimatic.client.rest.getPredicateInfo(
        {input: pred.input, predicateProviderClass: pred.predicateProviderClass}
      ).done( (data) =>
        console.log data
        if data.success and data.elements?
          @elements(data.elements)
      )
      console.log pred

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

    addCondition: =>
      @conditionInput.parentOp = null
      @conditionInput.visible(true)
      @conditionInput.value("")
      @conditionInput.refreshDefaults()
      $('#rule-condition-input').focus()

    addAnd: (ele) => @addBinaryOp('and', ele)

    addOr: (ele) =>  @addBinaryOp('or', ele)

    addBinaryOp: (type, ele) ->
      newBinOp =  {type, left: ele, right: null}
      if ele.parent?
        if ele.parent.left is ele
          ele.parent.left = newBinOp
        else
          ele.parent.right = newBinOp
        ele.parent = newBinOp
        @tree(@tree())
      else
        ele.parent = newBinOp
        @tree(newBinOp)

      @conditionInput.parentOp = newBinOp
      @conditionInput.visible(true)
      @conditionInput.value("")
      $('#rule-condition-input').focus()

    constructor: ->
      @ruleAsText = ko.computed( => "if #{@ruleCondition()} then #{@ruleActions()}")
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
          else throw new Error("Illegal rule action: #{action()}")
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

  try
    pimatic.pages.editRule = new EditRuleViewModel()
  catch e
    TraceKit.report(e)
  return
)

$(document).on("pagecreate", '#edit-rule', (event) ->
  try
    ko.applyBindings(pimatic.pages.editRule, $('#edit-rule')[0])

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
            if data.hints.tree?
              editRulePage.tree(data.hints.tree)
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

$(document).on("pagebeforehide", '#edit-rule', (event) ->
  try
    pimatic.pages.editRule.autocompleteAjax?.abort()
  catch e
    TraceKit.report(e)
)
