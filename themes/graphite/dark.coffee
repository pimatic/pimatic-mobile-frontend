base = require './base'

# BASE_COLOR, SECONDARY_COLOR, HIGHLIGHT_COLOR
theme = base '#007dcd', '#0093EA', '#005994'
theme.name = "water"
theme.extraCss.push 'themes/graphite/dark.custom.css'

overwrites = {
  'pm-listdivider-color': '#007dcd'
  'a-body-border': '#151515'
  'pm-flipswitch-on-color': '#c4c4c4'
  'pm-flipswitch-off-color': '#808080'
  'a-body-background-color': '#212121'
  'a-body-color': '#c4c4c4'
  'a-body-border': '#151515'
  # 'a-bar-background-color': '#171717'
  'a-bar-border': '#007dcd'
  # 'a-bar-color': '#c4c4c4'
  'a-page-background-color': '#171717'
  'a-page-border': '#171717'
  'a-page-color': '#C4C4C4'
  'a-bup-background-color': '#202020'
  'a-bup-border': '#151515'
  'a-bup-color': '#ffffff'
  'a-bup-shadow-color': '#151515'
  'a-bhover-color': '#fff'
  'a-bhover-shadow-color': '#151515'
  'a-bdown-border': '#151515'
  'a-bdown-color': '#ffffff'
}

for k,v of overwrites
  theme.variables[k] = v

module.exports = theme