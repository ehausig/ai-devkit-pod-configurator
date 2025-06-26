# Theme Customization

The AI DevKit Pod Configurator includes a sophisticated theme system for customizing the Terminal User Interface (TUI) appearance.

## Using Built-in Themes

Set the theme using the `AI_DEVKIT_THEME` environment variable:

```bash
# Available themes: default, dark, matrix, ocean, minimal, neon
AI_DEVKIT_THEME=matrix ./build-and-deploy.sh
```

## Built-in Themes

### Default Theme
The default colorful theme with good contrast and readability.

### Dark Theme
Softer colors optimized for dark terminals:
- Muted colors to reduce eye strain
- Gray borders and accents
- Cyan highlights

### Matrix Theme
Green-on-black theme inspired by The Matrix:
- All green color palette
- Perfect for that hacker aesthetic
- High contrast monochrome

### Ocean Theme
Blues and cyans for a calm appearance:
- Blue and cyan color scheme
- Soothing water-inspired palette
- Good for long coding sessions

### Minimal Theme
Mostly white and gray for a clean look:
- Monochrome design
- Reduced visual clutter
- Focus on content

### Neon Theme
High contrast with bright colors:
- Vibrant, eye-catching colors
- Perfect for demos
- Maximum visual impact

## Creating Custom Themes

To create a custom theme, modify the `load_theme()` function in `build-and-deploy.sh`:

```bash
"custom")
    # Custom theme - your colors here
    GLOBAL_SEPARATOR_COLOR="$COLOR_MAGENTA"
    GLOBAL_TITLE_STYLE="$BOLD_MAGENTA"
    # ... set all theme variables
    ;;
```

## Theme Variables

### Global Elements

```bash
GLOBAL_TITLE_STYLE          # Main title styling
GLOBAL_SEPARATOR_COLOR      # Separator lines (deprecated)
GLOBAL_HINT_STYLE          # Hint messages
```

### Catalog Box (Available Components)

```bash
CATALOG_BORDER_COLOR        # Box border color
CATALOG_TITLE_STYLE        # "Available Components" title
CATALOG_CATEGORY_STYLE     # Category headers (Languages, etc.)
CATALOG_CURSOR_COLOR       # Selection cursor (▸)
CATALOG_ITEM_SELECTED_STYLE    # Selected items
CATALOG_ITEM_AVAILABLE_STYLE   # Available items
CATALOG_ITEM_DISABLED_STYLE    # Disabled items
CATALOG_STATUS_IN_STACK_STYLE  # "(in stack)" text
CATALOG_STATUS_REQUIRED_STYLE  # "* requires X" text
CATALOG_PAGE_INDICATOR_STYLE   # "Page 1/2" text
CATALOG_ICON_SELECTED_COLOR    # ✓ icon color
CATALOG_ICON_AVAILABLE_COLOR   # ○ icon color
CATALOG_ICON_DISABLED_COLOR    # Disabled ○ icon
CATALOG_ICON_WARNING_COLOR     # Warning icon color
```

### Cart Box (Build Stack)

```bash
CART_BORDER_COLOR          # Box border color
CART_TITLE_STYLE          # "Build Stack" title
CART_CATEGORY_STYLE       # Category headers
CART_CURSOR_COLOR         # Selection cursor
CART_ITEM_STYLE          # Selected component names
CART_BASE_CATEGORY_STYLE  # "Base Development Tools"
CART_BASE_ITEM_STYLE     # Base tool names
CART_REMOVE_HINT_STYLE   # "[DEL to remove]" hint
CART_COUNT_STYLE         # "X selected" count
```

### Instructions Bar

```bash
INSTRUCTION_KEY_STYLE     # Keyboard shortcuts
INSTRUCTION_TEXT_STYLE    # Instruction text
INSTRUCTION_ABORT_STYLE   # Cancel/quit styling
```

### Summary Screen

```bash
SUMMARY_BORDER_COLOR      # Box border
SUMMARY_TITLE_STYLE      # Title styling
SUMMARY_CHECKMARK_COLOR  # ✓ checkmark
SUMMARY_CATEGORY_STYLE   # Category headers
```

### Deployment Status

```bash
STATUS_BORDER_COLOR          # Box border
STATUS_TITLE_STYLE          # "Deployment Status" title
STATUS_INITIAL_BULLET_COLOR  # Initial state bullet
STATUS_INITIAL_TEXT_COLOR    # Initial state text
STATUS_PENDING_BULLET_COLOR  # Pending state bullet
STATUS_PENDING_TEXT_COLOR    # Pending state text
STATUS_SUCCESS_BULLET_COLOR  # Success bullet (✓)
STATUS_SUCCESS_TEXT_COLOR    # Success text
STATUS_FAILED_BULLET_COLOR   # Failed bullet (✗)
STATUS_FAILED_TEXT_COLOR     # Failed text
STATUS_INFO_COLOR           # Info messages
```

### Logging

```bash
LOG_ERROR_STYLE    # Error messages
LOG_SUCCESS_STYLE  # Success messages
LOG_WARNING_STYLE  # Warning messages
LOG_INFO_STYLE     # Info messages
LOG_DEFAULT_STYLE  # Default log style
```

## Available Colors

### Base Colors

```bash
COLOR_BLACK, COLOR_RED, COLOR_GREEN, COLOR_YELLOW
COLOR_BLUE, COLOR_MAGENTA, COLOR_CYAN, COLOR_WHITE
COLOR_GRAY
```

### Custom Colors

```bash
COLOR_SILVER      # #ABB2BF
COLOR_CHARCOAL    # #5C6370
COLOR_SKY         # #61AFEF
COLOR_SAGE        # #B2C179
COLOR_CORAL       # #E06C75
COLOR_SAND        # #E5C07B
COLOR_SEAFOAM     # #8ABFB7
COLOR_LAVENDER    # #C678DD
```

### Bright Colors

```bash
COLOR_BRIGHT_RED, COLOR_BRIGHT_GREEN, COLOR_BRIGHT_YELLOW
COLOR_BRIGHT_BLUE, COLOR_BRIGHT_MAGENTA, COLOR_BRIGHT_CYAN
COLOR_BRIGHT_WHITE, COLOR_BRIGHT_SILVER, COLOR_BRIGHT_CHARCOAL
COLOR_BRIGHT_SKY, COLOR_BRIGHT_SAGE, COLOR_BRIGHT_CORAL
COLOR_BRIGHT_SAND, COLOR_BRIGHT_SEAFOAM, COLOR_BRIGHT_LAVENDER
```

### Styles

```bash
STYLE_BOLD        # Bold text
STYLE_DIM         # Dimmed text
STYLE_ITALIC      # Italic text
STYLE_UNDERLINE   # Underlined text
STYLE_BLINK       # Blinking text
STYLE_REVERSE     # Reversed colors
STYLE_RESET       # Reset all styles
```

### Compound Styles

```bash
BOLD_RED, BOLD_GREEN, BOLD_YELLOW, BOLD_BLUE
BOLD_MAGENTA, BOLD_CYAN, BOLD_WHITE, BOLD_BRIGHT_WHITE
BOLD_SILVER, BOLD_CHARCOAL, BOLD_SKY, BOLD_SAGE
BOLD_CORAL, BOLD_SAND, BOLD_SEAFOAM, BOLD_LAVENDER
```

## Creating a Complete Custom Theme

Here's an example of creating a "Cyberpunk" theme:

```bash
"cyberpunk")
    # Cyberpunk theme - neon pink and blue
    GLOBAL_TITLE_STYLE="$BOLD_BRIGHT_MAGENTA"
    GLOBAL_HINT_STYLE="$COLOR_BRIGHT_CYAN"
    
    # Catalog styling
    CATALOG_BORDER_COLOR="$COLOR_BRIGHT_MAGENTA"
    CATALOG_TITLE_STYLE="$BOLD_BRIGHT_CYAN"
    CATALOG_CATEGORY_STYLE="$COLOR_BRIGHT_YELLOW"
    CATALOG_CURSOR_COLOR="$COLOR_BRIGHT_MAGENTA"
    CATALOG_ITEM_SELECTED_STYLE="$COLOR_BRIGHT_CYAN"
    CATALOG_ITEM_AVAILABLE_STYLE="$COLOR_BRIGHT_WHITE"
    CATALOG_ITEM_DISABLED_STYLE="$COLOR_GRAY"
    CATALOG_STATUS_IN_STACK_STYLE="$COLOR_BRIGHT_GREEN"
    CATALOG_STATUS_REQUIRED_STYLE="$COLOR_BRIGHT_YELLOW"
    CATALOG_PAGE_INDICATOR_STYLE="$COLOR_BRIGHT_MAGENTA"
    CATALOG_ICON_SELECTED_COLOR="$COLOR_BRIGHT_CYAN"
    CATALOG_ICON_AVAILABLE_COLOR="$COLOR_WHITE"
    CATALOG_ICON_DISABLED_COLOR="$COLOR_GRAY"
    CATALOG_ICON_WARNING_COLOR="$COLOR_BRIGHT_YELLOW"
    
    # Cart styling
    CART_BORDER_COLOR="$COLOR_BRIGHT_CYAN"
    CART_TITLE_STYLE="$BOLD_BRIGHT_MAGENTA"
    CART_CATEGORY_STYLE="$COLOR_BRIGHT_YELLOW"
    CART_CURSOR_COLOR="$COLOR_BRIGHT_CYAN"
    CART_ITEM_STYLE="$COLOR_BRIGHT_WHITE"
    CART_BASE_CATEGORY_STYLE="$COLOR_BRIGHT_YELLOW"
    CART_BASE_ITEM_STYLE="$COLOR_WHITE"
    CART_REMOVE_HINT_STYLE="$COLOR_BRIGHT_RED"
    CART_COUNT_STYLE="$COLOR_BRIGHT_MAGENTA"
    
    # Instructions
    INSTRUCTION_KEY_STYLE="$COLOR_BRIGHT_CYAN"
    INSTRUCTION_TEXT_STYLE="$COLOR_WHITE"
    INSTRUCTION_ABORT_STYLE="$COLOR_BRIGHT_RED"
    
    # Summary screen
    SUMMARY_BORDER_COLOR="$COLOR_BRIGHT_MAGENTA"
    SUMMARY_TITLE_STYLE="$BOLD_BRIGHT_CYAN"
    SUMMARY_CHECKMARK_COLOR="$COLOR_BRIGHT_GREEN"
    SUMMARY_CATEGORY_STYLE="$COLOR_BRIGHT_YELLOW"
    
    # Status
    STATUS_BORDER_COLOR="$COLOR_BRIGHT_CYAN"
    STATUS_TITLE_STYLE="$BOLD_BRIGHT_MAGENTA"
    STATUS_PENDING_STYLE="$COLOR_BRIGHT_YELLOW"
    STATUS_RUNNING_STYLE="$COLOR_BRIGHT_CYAN"
    STATUS_SUCCESS_STYLE="$COLOR_BRIGHT_GREEN"
    STATUS_FAILED_STYLE="$COLOR_BRIGHT_RED"
    
    # Logging
    LOG_ERROR_STYLE="$COLOR_BRIGHT_RED"
    LOG_SUCCESS_STYLE="$COLOR_BRIGHT_GREEN"
    LOG_WARNING_STYLE="$COLOR_BRIGHT_YELLOW"
    LOG_INFO_STYLE="$COLOR_BRIGHT_CYAN"
    LOG_DEFAULT_STYLE="$COLOR_BRIGHT_MAGENTA"
    ;;
```

## Testing Your Theme

1. Add your theme to the `load_theme()` function
2. Test with different terminal backgrounds:
   ```bash
   AI_DEVKIT_THEME=cyberpunk ./build-and-deploy.sh
   ```
3. Navigate through all screens to verify readability
4. Test in different terminal emulators

## Theme Design Guidelines

1. **Contrast**: Ensure sufficient contrast between text and background
2. **Consistency**: Use consistent colors for similar elements
3. **Readability**: Test with both light and dark terminal backgrounds
4. **Accessibility**: Consider colorblind users
5. **Purpose**: Use color to convey meaning (red=error, green=success)

## Terminal Compatibility

The theme system uses ANSI escape codes that work in most modern terminals:
- iTerm2 (macOS)
- Terminal.app (macOS)
- GNOME Terminal (Linux)
- Konsole (Linux)
- Windows Terminal (Windows)
- VS Code integrated terminal

## Sharing Themes

To share your custom theme:

1. Extract your theme case from `load_theme()`
2. Document the color choices and inspiration
3. Include screenshots with different backgrounds
4. Submit a pull request to add it as a built-in theme

## Troubleshooting

### Colors Not Displaying Correctly

1. Check terminal supports 256 colors:
   ```bash
   echo $TERM  # Should show xterm-256color or similar
   ```

2. Some terminals need configuration:
   ```bash
   export TERM=xterm-256color
   ```

3. Verify terminal emulator settings for ANSI color support

### Theme Not Loading

1. Check environment variable is set correctly
2. Verify theme name matches exactly (case-sensitive)
3. Check for syntax errors in theme definition

### Poor Readability

1. Adjust terminal's base colors/profile
2. Try a different built-in theme
3. Modify specific colors that clash with your setup
