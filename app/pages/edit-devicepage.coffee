# edit-variable-page
# --------------

$(document).on("pagebeforecreate", (event) ->
  if pimatic.pages.editDevicepage? then return
  
  class EditDevicepageViewModel

    action: ko.observable('add')
    pageName: ko.observable('')
    pageId: ko.observable('')

    constructor: ->
      @pageTitle = ko.computed( => 
        return (if @action() is 'add' then __('Add New Page') else __('Edit Page'))
      )
      pimatic.autoFillId(@pageName, @pageId, @action)

    resetFields: () ->
      @pageName('')
      @pageId('')

    onSubmit: ->
      unless pimatic.isValidId(@pageId())
        alert __(pimatic.invalidIdMessage)
        return

      params = {
        pageId: @pageId()
        page: 
          name: @pageName()
      }

      (
        switch @action()
          when 'add' then pimatic.client.rest.addPage(params)
          when 'update' then pimatic.client.rest.updatePage(params)
          else throw new Error("Illegal devicepage action: #{action()}")
      ).done( (data) ->
        if data.success then $.mobile.changePage '#devicepages-page', {transition: 'slide', reverse: true}   
        else alert data.error
      ).fail(ajaxAlertFail)
      return false

    onRemove: ->
      really = confirm(__("Do you really want to delete the %s page?", @pageName()))
      if really
        pimatic.client.rest.removePage({pageId: @pageId()})
          .done( (data) ->
            if data.success then $.mobile.changePage '#devicepages-page', {transition: 'slide', reverse: true}   
            else alert data.error
          ).fail(ajaxAlertFail)
        return false

  try
    pimatic.pages.editDevicepage = new EditDevicepageViewModel()
  catch e
    TraceKit.report(e)
  return
)

$(document).on("pagecreate", '#edit-devicepage-page', (event) ->
  try
    ko.applyBindings(pimatic.pages.editDevicepage, $('#edit-devicepage-page')[0])
  catch e
    TraceKit.report(e)
)

$(document).on("pagebeforeshow", '#edit-devicepage-page', (event) ->
  editDevicepage = pimatic.pages.editDevicepage
  params = jQuery.mobile.pageParams
  jQuery.mobile.pageParams = {}
  if params?.action is "update"
    page = params.page
    editDevicepage.action('update')
    editDevicepage.pageId(page.id)
    editDevicepage.pageName(page.name())
  else
    editDevicepage.resetFields()
    editDevicepage.action('add')
  return
)