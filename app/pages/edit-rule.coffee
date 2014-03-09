# edit-rule-page
# --------------

$(document).on "pageinit", '#edit-rule', (event) ->
  $('#edit-rule').on "submit", '#edit-rule-form', ->
    ruleId = $('#edit-rule-id').val()
    ruleCondition = $('#edit-rule-condition').val()
    ruleActions = $('#edit-rule-actions').val()
    ruleText = "if #{ruleCondition} then #{ruleActions}"
    ruleEnabled = $('#edit-rule-active').is(':checked')
    action = $('#edit-rule-form').data('action')
    $.post("/api/rule/#{ruleId}/#{action}", 
      rule: ruleText
      active: ruleEnabled
    ).done( (data) ->
        if data.success then $.mobile.changePage '#index', {transition: 'slide', reverse: true}   
        else alert data.error
      ).fail(ajaxAlertFail)
    return false

  $('#edit-rule').on "click", '#edit-rule-remove', ->
    ruleId = $('#edit-rule-id').val()
    $.get("/api/rule/#{ruleId}/remove")
      .done( (data) ->
        if data.success then $.mobile.changePage '#index', {transition: 'slide', reverse: true}   
        else alert data.error
      ).fail(ajaxAlertFail)
    return false

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
    match: /^((?:[^"]*"[^"]*")*[^"]*\sand\s)*(.*)$/
    search: (term, callback) ->
      if pimatic.pages.editRule.autocompleEnabled
        editRulePage.autocompleteAjax?.abort()
        editRulePage.autocompleteAjax = $.ajax('parseAction',
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
    index: 2
    replace: customReplace
    template: customTemplate
  ])


  $(document).on "pagebeforeshow", '#edit-rule', (event) ->
    $('#edit-rule-active').checkboxradio "refresh"
    action = $('#edit-rule-form').data('action')
    switch action
      when 'add'
        $('#edit-rule h3').text __('Add new rule')
        $('#edit-rule-id').textinput('enable')
        $('#edit-rule-advanced').hide()
      when 'update'
        $('#edit-rule h3').text __('Edit rule')        
        $('#edit-rule-id').textinput('disable')
        $('#edit-rule-advanced').show()
    # refrash height the dirty way
    pimatic.pages.editRule.autocompleEnabled = no
    $("#edit-rule-form textarea").css("height", 50).keyup()
    pimatic.pages.editRule.autocompleEnabled = yes


  $(document).on "pagebeforehide", '#edit-rule', (event) ->
    pimatic.pages.editRule.autocompleteAjax?.abort()


pimatic.pages.editRule = 
  autocompleteAjax: null
  autocompleEnabled: no