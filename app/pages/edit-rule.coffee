# edit-rule-page
# --------------

$(document).on("pagebeforecreate", (event) ->
  if pimatic.pages.editRule? then return

  class EditRuleViewModel

    autocompleteAjax: null
    autocompleEnabled: no

    action: ko.observable('add')
    ruleId: ko.observable('')
    ruleName: ko.observable('')
    ruleCondition: ko.observable('')
    ruleActions: ko.observable('')
    ruleEnabled: ko.observable(no)

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
      @ruleEnabled('')

    onSubmit: ->
      $.post("/api/rule/#{@ruleId()}/#{@action()}", 
        rule: @ruleAsText()
        active: @ruleEnabled()
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

  pimatic.pages.editRule = new EditRuleViewModel()
  return
)

$(document).on("pagecreate", '#edit-rule', (event) ->
  ko.applyBindings(pimatic.pages.editRule, $('#edit-rule')[0])

  customReplace = (pre, value) -> 
    commonPart = this.ac.getCommonPart(pre, value)
    return pre + value.substring(commonPart.length, value.length)

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
      if pimatic.pages.editRule.autocompleEnabled
        editRulePage.autocompleteAjax = $.ajax('parseCondition',
          type: 'POST'
          data: {condition: term}
          global: false
        ).done( (data) =>
          autocomplete = data.context?.autocomplete or []
          if data.error then console.log data.error
          @lastTerm = term
          callback autocomplete
        ).fail( => callback [] )
      else callback []
    index: 1
    replace: customReplace
    template: customTemplate
  ])

  $("#edit-rule-actions").textcomplete([
    match: /^(.*)$/
    search: (term, callback) ->
      if pimatic.pages.editRule.autocompleEnabled
        editRulePage.autocompleteAjax?.abort()
        editRulePage.autocompleteAjax = $.ajax('parseActions',
          type: 'POST'
          data: {action: term}
          global: false
        ).done( (data) =>
          autocomplete = data.context?.autocomplete or []
          if data.message? and data.message.length > 0
            pimatic.showToast data.message[0]
          if data.error then console.log data.error
          @lastTerm = term
          callback autocomplete
        ).fail( => callback [] )
      else callback []
    index: 1
    replace: customReplace
    template: customTemplate
  ])
)

$(document).on("pagebeforeshow", '#edit-rule', (event) ->
  pimatic.pages.editRule.autocompleEnabled = no
  $("#edit-rule-form textarea").css("height", 50).keyup()
  pimatic.pages.editRule.autocompleEnabled = yes
)

$(document).on("pagebeforehide", '#edit-rule', (event) ->
  pimatic.pages.editRule.autocompleteAjax?.abort()
)
