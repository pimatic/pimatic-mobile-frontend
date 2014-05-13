module.exports = (env) ->

  Q = env.require 'q'
  _ = env.require 'lodash'
  M = env.matcher

  class ButtonPredicateProvider extends env.predicates.PredicateProvider

    _listener: {}

    constructor: (@mobile) ->

    parsePredicate: (input, context) ->

      matchCount = 0
      matchingButton = 0
      end = () => matchCount++
      onButtonMatch = (m, button) => matchingButton = button

      allButtons = _(@mobile.config.items)
        .filter((i) => i.type is "button")
        .map((i) => [i, i.text]).value()

      m = M(input, context)
        .match('the ', optional: true)
        .match(allButtons, onButtonMatch)
        .match(' button', optional: true)
        .match(' is', optional: true)
        .match(' pressed')

      if m.hadMatch()
        match = m.getFullMatch()
        return {
          token: match
          nextInput: input.substring(match.length)
          predicateHandler: new ButtonPredicateHandler(this, matchingButton.itemId)
        }
      return null

  class ButtonPredicateHandler extends env.predicates.PredicateHandler

    constructor: (@provider, @itemId) ->

    setup: ->
      @buttonPressedListener = (item) => if item.itemId is @itemId then @emit('change', 'event')
      @provider.mobile.on 'button pressed', @buttonPressedListener
      super()
    getValue: -> Q(false)
    destroy: -> 
      @provider.mobile.removeListener 'button pressed', @buttonPressedListener
      super()
    getType: -> 'event'


  return ButtonPredicateProvider
