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
