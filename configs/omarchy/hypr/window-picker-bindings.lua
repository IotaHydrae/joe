local window_picker = os.getenv("HOME") .. "/.local/bin/omarchy-window-picker"
o.rebind("ALT + TAB", "Choose a window", window_picker)
o.rebind("ALT + SHIFT + TAB", "Choose a window", window_picker)
