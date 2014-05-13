# edit-rule-page
# --------------

$(document).on("pagebeforecreate", (event) ->
  if pimatic.pages.editRule? then return

  class EditRuleViewModel

    autocompleteAjax: null
    autocompleEnabled: yes

    action: ko.observable('add')
    ruleId: ko.observable('')
    ruleName: ko.observable('')
    ruleCondition: ko.observable('')
    ruleActions: ko.observable('')
    ruleEnabled: ko.observable(yes)

    constructor: ->
      @ruleAsText = ko.computed( => "if #{@ruleCondition()} then #{@ruleActions()}")
      @pageTitle = ko.computed( => 
        return (if @action() is 'add' then __('Add new rule') else __('Edit rule'))
      )

    resetFields: () ->
      @ruleId('')
      @ruleName('')
      @ruleCondition('')
      @ruleActions('')
      @ruleEnabled(yes)

    onSubmit: ->
      $.post("/api/rule/#{@ruleId()}/#{@action()}", 
        rule: @ruleAsText()
        active: @ruleEnabled()
        name: @ruleName()
      ).done( (data) ->
          if data.success then $.mobile.changePage '#index', {transition: 'slide', reverse: true}   
          else alert data.error
      ).fail(ajaxAlertFail)
      return false

    onRemove: ->
      $.get("/api/rule/#{@ruleId()}/remove")
        .done( (data) ->
          if data.success then $.mobile.changePage '#index', {transition: 'slide', reverse: true}   
          else alert data.error
        ).fail(ajaxAlertFail)
      return false

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
          editRulePage.autocompleteAjax = $.ajax('parseCondition',
            type: 'POST'
            data: {condition: term}
            global: false
          ).done( (data) =>
            result.autocomplete = data.context?.autocomplete or []
            result.format = data.context?.format or []
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
      template: customTemplate
    ])

    $("#edit-rule-actions").textcomplete([
      match: /^(.*)$/
      search: (term, callback) ->
        result = {autocomplete: [], format: []}
        if pimatic.pages.editRule.autocompleEnabled
          editRulePage.autocompleteAjax?.abort()
          editRulePage.autocompleteAjax = $.ajax('parseActions',
            type: 'POST'
            data: {action: term}
            global: false
          ).done( (data) =>
            result.autocomplete = data.context?.autocomplete or []
            result.format = data.context?.format or []
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
