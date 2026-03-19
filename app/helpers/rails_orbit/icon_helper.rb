module RailsOrbit
  module IconHelper
    ICONS = {
      overview:  '<svg class="orbit-nav__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="14" y="14" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/></svg>',
      jobs:      '<svg class="%{css_class}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="3" width="20" height="14" rx="2"/><path d="M8 21h8"/><path d="M12 17v4"/></svg>',
      cache:     '<svg class="%{css_class}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><ellipse cx="12" cy="5" rx="9" ry="3"/><path d="M3 5v14a9 3 0 0 0 18 0V5"/><path d="M3 12a9 3 0 0 0 18 0"/></svg>',
      errors:    '<svg class="%{css_class}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>',
      orbit:     '<svg class="orbit-nav__logo" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="3"/><circle cx="12" cy="12" r="8" stroke-dasharray="4 3"/></svg>',
      delta_up:  '<svg class="orbit-delta__icon" viewBox="0 0 12 12" fill="currentColor"><path d="M6 2L10 7H2z"/></svg>',
      delta_down:'<svg class="orbit-delta__icon" viewBox="0 0 12 12" fill="currentColor"><path d="M6 10L2 5h8z"/></svg>',
    }.freeze

    def orbit_icon(name, css_class: "orbit-icon")
      template = ICONS[name.to_sym]
      return "" unless template
      (template % { css_class: css_class }).html_safe
    end
  end
end
