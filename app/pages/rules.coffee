# index-page
# ----------
tc = pimatic.tryCatch

$(document).on( "pagebeforecreate", '#rules-page', tc (event) ->

  class RulesViewModel

    enabledEditing: ko.observable(no)
    ruleItemCssClass: ko.observable('')
    isSortingRules: ko.observable(no)

    constructor: () ->
      @rules = pimatic.rules

      @rulesListViewRefresh = ko.computed( tc =>
        @rules()
        @isSortingRules()
        @enabledEditing()
        pimatic.try( => $('#rules').listview('refresh').addClass("dark-background") )
      ).extend(rateLimit: {timeout: 1, method: "notifyWhenChangesStop"})

      @lockButton = ko.computed( tc => 
        editing = @enabledEditing()
        return {
          icon: (if editing then 'check' else 'gear')
        }
      )


    afterRenderRule: (elements, rule) ->
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

    onDropRuleOnTrash: (rule) ->
      really = confirm(__("Do you really want to delete the %s rule?", rule.name()))
      if really then (doDeletion = =>
          pimatic.loading "deleterule", "show", text: __('Saving')
          pimatic.client.rest.removeRule(ruleId: @rule.id).done( (data) =>
            if data.success
              @rules.remove(rule)
          ).always( => 
            pimatic.loading "deleterule", "hide"
          ).done(ajaxShowToast).fail(ajaxAlertFail)
        )()

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
      editRulePage.ruleCondition(rule.conditionToken())
      editRulePage.ruleActions(rule.actionsToken())
      editRulePage.ruleEnabled(rule.active())
      editRulePage.ruleLogging(rule.logging())
      return true

  pimatic.pages.rules = rulesPage = new RulesViewModel()

)

$(document).on("pagecreate", '#rules-page', tc (event) ->
  rulesPage = pimatic.pages.rules
  try
    ko.applyBindings(rulesPage, $('#rules-page')[0])
  catch e
    TraceKit.report(e)
    pimatic.storage?.removeAll()
    window.location.reload()

  $("#rules .handle").disableSelection()
  return
)

$(document).on("pagebeforeshow", '#rules-page', tc (event) ->
  pimatic.try( => $('#rules').listview('refresh').addClass("dark-background") )
)






