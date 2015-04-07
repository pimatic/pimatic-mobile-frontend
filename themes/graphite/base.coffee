Colour = require 'colour.js'

module.exports = (BASE_COLOR, SECONDARY_COLOR, HIGHLIGHT_COLOR) ->
  theme = {
    'css': [
      'app/css/themes/default/jquery.mobile-1.4.5.css'
    ],
    'extraCss': [
      'themes/graphite/base.extra.css'
    ]
    'removeCss': [
      '.ui-bar-a|text-shadow'
      '.ui-btn-up-a|text-shadow'
      '.ui-btn-hover-a|text-shadow'
      '.ui-btn-down-a|text-shadow'
      '.ui-bar-b|text-shadow'
      '.ui-body-a, .ui-overlay-a|text-shadow'
      '.ui-body-c, .ui-overlay-c|text-shadow'
    ]
  }

  baseColor = new Colour BASE_COLOR
  baseColorDarker = baseColor.shiftshade(-0.1).hex()

  theme.variables = {
    'global-font-family': 'Helvetica,Arial,sans-serif'
    'global-radii-blocks': '0.2em'
    'global-radii-buttons': '0.8em'
    'global-box-shadow-size': '1px'
    'global-box-shadow-color': 'rgba(0,0,0,0.2)'

    # Pages
    'a-page-background-color': '#eee'
    'a-page-shadow-y': '0px'
    'a-page-shadow-x': '0px'
    'b-page-shadow-y': '0px'
    'b-page-shadow-x': '0px'
    'a-page-shadow-radius': '0px'

    # Toolbars
    'a-bar-border': HIGHLIGHT_COLOR
    'b-bar-border': HIGHLIGHT_COLOR
    'a-bar-background-color': BASE_COLOR
    'b-bar-background-color': BASE_COLOR
    'a-bar-background-start': SECONDARY_COLOR
    'a-bar-background-end': BASE_COLOR
    'a-bar-dropshadow-color': 'rgba(0,0,0,0.15)'
    'a-bar-color': '#fff'
    'a-bar-shadow-y': '0px'
    'a-bar-shadow-color': baseColorDarker
    'a-active-shadow-color': baseColorDarker

    # Typography
    'a-link-color': BASE_COLOR
    'a-link-hover': SECONDARY_COLOR
    'a-link-visited': BASE_COLOR
    'a-link-active': BASE_COLOR

    'a-active-background-color': BASE_COLOR

    # Buttons
    'global-active-background-color': BASE_COLOR
    'global-active-background-start': BASE_COLOR
    'global-active-background-end': BASE_COLOR
    'global-active-border': SECONDARY_COLOR

    'a-header-bhover-background-color': SECONDARY_COLOR
    'a-header-bhover-border': HIGHLIGHT_COLOR
    'a-header-bhover-color': '#fff'

    'a-body-shadow-y': '0px'
    'b-body-shadow-y': '0px'

    'a-bup-border': "#ccc"
    'a-bup-background-color': '#fff'
    'a-bhover-background-color': SECONDARY_COLOR
    'a-bhover-border': BASE_COLOR
    'a-bhover-color': '#fff'
    'a-bdown-background-color': BASE_COLOR
    'a-bup-color': '#000'
    'a-bhover-shadow-y': '0px'
    'a-bup-shadow-y': '0px'
    'a-bdown-shadow-y': '0px'
    'a-active-shadow-y': '0px'
    'a-active-border': BASE_COLOR
    'a-bdown-shadow-color': '#000'

    'b-bup-border': BASE_COLOR
    'b-bdown-background-color': BASE_COLOR
    'b-bhover-border': BASE_COLOR
    'b-bup-background-color': SECONDARY_COLOR
    'b-bhover-background-color': BASE_COLOR
    'b-bhover-color': '#fff'
    'b-bdown-background-start': BASE_COLOR
    'b-bdown-background-end': BASE_COLOR
    'b-active-background-color': BASE_COLOR
    'b-page-shadow-radius': '0px'
    'b-bar-shadow-y': '0px'
    'b-bhover-shadow-y': '0px'
    'b-bup-shadow-y': '0px'
    'b-bdown-shadow-y': '0px'
    'b-active-shadow-y': '0px'
    'b-bdown-shadow-color': '#000'
    'b-active-border': BASE_COLOR
    'b-bup-shadow-color': baseColorDarker

    'base_color': BASE_COLOR 
    'secondary_color': SECONDARY_COLOR
    'highlight_border_color': HIGHLIGHT_COLOR

    'pm-listdivider-color': baseColorDarker
  }
  return theme
