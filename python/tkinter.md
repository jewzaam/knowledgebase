# Tkinter Behavior and Quirks

Facts about Tkinter GUI toolkit behavior, platform-specific quirks, and API
mechanics.

## Menu Keyboard Shortcuts

The `underline` parameter on `Menu.add_command()` only draws a visual underline
on the specified character — it does NOT create a keyboard binding. The visual
underline is a hint for mnemonics, but the mnemonic traversal itself requires
either menu-bar integration (which provides Alt+letter) or explicit bindings.

On Linux with XWayland, `tk_popup()` menus do not reliably receive keyboard
focus. Even when Tk's built-in mnemonic traversal is available (menu bar
context), it may not work for context menus. This means relying solely on
`underline` leaves users with no functional keyboard shortcuts in popup menus.

Working menu keyboard shortcuts require:

1. Explicit `bind_all()` bindings created after the menu is posted
2. Cleanup (unbind) when the menu is dismissed

The bind must be created *after* posting because Tk's event dispatch respects
binding order, and `tk_popup()` may post the menu in a way that interferes with
pre-existing bindings. Create the binding right after `tk_popup()` returns, and
remove it in a menu teardown handler or when the menu loses focus.

Example pattern:

```python
def show_popup_menu(event):
    menu = tk.Menu(root, tearoff=0)
    menu.add_command(label="Action", underline=0, command=do_action)
    menu.tk_popup(event.x_root, event.y_root)
    
    # Create explicit binding after posting
    def handle_shortcut(e):
        do_action()
        menu.unpost()
    
    binding_id = root.bind_all("<Control-a>", handle_shortcut)
    
    # Cleanup on menu dismiss
    def cleanup():
        root.unbind_all("<Control-a>", binding_id)
    
    menu.bind("<Unmap>", lambda e: cleanup())
```

The `underline` parameter remains useful for visual consistency, but treat it
as decoration only. Functional keyboard shortcuts need explicit bindings.

## Unicode Rendering

Tkinter on Linux (with Noto Sans or similar fonts) cannot render Unicode
characters above U+FFFF (supplementary plane). Characters like 🔄 (U+1F504)
and 🎤 (U+1F3A4) appear as empty boxes or are invisible. BMP characters
(U+0000–U+FFFF) render correctly — e.g., ⚙ (U+2699), ◀ (U+25C0), ↻ (U+21BB).

Workaround: use BMP equivalents for all button and label text. The
supplementary-plane limitation appears specific to Tkinter's font rendering
path on Linux; the same characters may work in terminal output or other GUI
toolkits.

## Canvas Scroll Events

When a `tk.Canvas` uses `create_window()` to embed a `tk.Frame` containing
child widgets (Labels, Buttons), the canvas itself never receives mouse events
like `<Button-4>` and `<Button-5>` (scroll). The child widgets consume the
events before the canvas sees them.

This breaks the common "scrollable frame via canvas" pattern for mousewheel
scrolling. Options:

1. Bind scroll handlers to every child widget recursively
2. Switch to a `tk.Text` widget with `window_create()`, which handles scrolling
   natively

The Text widget approach is more robust — it was designed for embedded widgets
and has built-in scroll coordination.

## ttk.Notebook Scroll-to-Change-Tab

`ttk.Notebook` has built-in behavior that changes the selected tab when the
user scrolls (Button-4/Button-5 on Linux, MouseWheel on Windows). This fires
even when the scroll event originates on a child widget inside a tab, causing
unexpected tab switches when the user is trying to scroll content within the
tab.

Disable with:

```python
notebook.bind("<Button-4>", lambda e: "break")
notebook.bind("<Button-5>", lambda e: "break")
notebook.bind("<MouseWheel>", lambda e: "break")
```

The `"break"` return value stops event propagation, preventing the notebook
from processing the scroll as a tab-change command.
