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
- Bright, vibrant colors
- High contrast for clarity
- Optimized for both light and dark terminals

### Dark Theme
Softer colors optimized for dark terminals:
- Muted colors to reduce eye strain
- Gray borders and accents
- Cyan highlights
- Perfect for late-night coding sessions

### Matrix Theme
Green-on-black theme inspired by The Matrix:
- All green color palette
- Perfect for that hacker aesthetic
- High contrast monochrome
- Nostalgic terminal feel

### Ocean Theme
Blues and cyans for a calm appearance:
- Blue and cyan color scheme
- Soothing water-inspired palette
- Good for long coding sessions
- Reduces visual fatigue

### Minimal Theme
Mostly white and gray for a clean look:
- Monochrome design
- Reduced visual clutter
- Focus on content
- Professional appearance

### Neon Theme
High contrast with bright colors:
- Vibrant pink and cyan accents
- Eye-catching colors
- Perfect for demos and presentations
- Maximum visual impact

## Theme Architecture

The theme system uses a comprehensive set of variables organized by UI components:

### Component Organization

1. **Global Elements** - Title bars, separators, hints
2. **Catalog Box** - Available components panel
3. **Cart Box** - Selected components panel
4. **Instructions Bar** - Keyboard shortcuts
5. **Summary Screen** - Pre-deployment review
6. **Deployment Status** - Build progress indicators

### Color System

The theme system supports:
- 256-color terminal palette
- Custom RGB colors (24-bit)
- ANSI standard colors
- Compound styles (bold + color)

## Creating Custom Themes

To create a custom theme, modify the `load_theme()` function in `build-and-deploy.sh`:

```bash
"custom")
    # Custom theme - your colors here
    GLOBAL_TITLE_STYLE="$BOLD_MAGENTA"
    GLOBAL_HINT_STYLE="$COLOR_BRIGHT_CYAN"
    # ... set all theme variables
    ;;
```

## Theme Variables Reference

### Global Elements

```bash
GLOBAL_TITLE_STYLE          # Main title styling
GLOBAL_SEPARATOR_COLOR      # Separator lines (deprecated)
GLOBAL_HINT_STYLE          # Hint messages
```

### Catalog Box (Available Components)

```bash
# Box styling
CATALOG_BORDER_COLOR        # Box border color
CATALOG_TITLE_STYLE        # "Available Components" title

# Content styling
CATALOG_CATEGORY_STYLE     # Category headers (Languages, etc.)
CATALOG_CURSOR_COLOR       # Selection cursor (▸)
CATALOG_ITEM_SELECTED_STYLE    # Selected items
CATALOG_ITEM_AVAILABLE_STYLE   # Available items
CATALOG_ITEM_DISABLED_STYLE    # Disabled items

# Status indicators
CATALOG_STATUS_IN_STACK_STYLE  # "(in stack)" text
CATALOG_STATUS_REQUIRED_STYLE  # "* requires X" text
CATALOG_PAGE_INDICATOR_STYLE   # "Page 1/2" text

# Icons
CATALOG_ICON_SELECTED_COLOR    # ✓ icon color
CATALOG_ICON_AVAILABLE_COLOR   # ○ icon color
CATALOG_ICON_DISABLED_COLOR    # Disabled ○ icon
CATALOG_ICON_WARNING_COLOR     # Warning icon color
```

### Cart Box (Build Stack)

```bash
# Box styling
CART_BORDER_COLOR          # Box border color
CART_TITLE_STYLE          # "Build Stack" title

# Content styling
CART_CATEGORY_STYLE       # Category headers
CART_CURSOR_COLOR         # Selection cursor
CART_ITEM_STYLE          # Selected component names

# Base components
CART_BASE_CATEGORY_STYLE  # "Base Development Tools"
CART_BASE_ITEM_STYLE     # Base tool names

# UI elements
CART_REMOVE_HINT_STYLE   # "[DEL to remove]" hint
CART_COUNT_STYLE         # "X selected" count
```

### Instructions Bar

```bash
INSTRUCTION_KEY_STYLE     # Keyboard shortcuts (↑↓, SPACE, etc.)
INSTRUCTION_TEXT_STYLE    # Instruction text
INSTRUCTION_ABORT_STYLE   # Cancel/quit styling (q key)
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
# Box styling
STATUS_BORDER_COLOR          # Box border
STATUS_TITLE_STYLE          # "Deployment Status" title

# Status indicators
STATUS_INITIAL_BULLET_COLOR  # Initial state bullet (-)
STATUS_INITIAL_TEXT_COLOR    # Initial state text
STATUS_PENDING_BULLET_COLOR  # Pending state bullet (○)
STATUS_PENDING_TEXT_COLOR    # Pending state text
STATUS_SUCCESS_BULLET_COLOR  # Success bullet (✓)
STATUS_SUCCESS_TEXT_COLOR    # Success text
STATUS_FAILED_BULLET_COLOR   # Failed bullet (✗)
STATUS_FAILED_TEXT_COLOR     # Failed text
STATUS_INFO_COLOR           # Info messages (→ details)

# Animation
STATUS_RUNNING_STYLE        # Running state (deprecated, uses bullets)
STATUS_PENDING_STYLE        # Pending animation
STATUS_SUCCESS_STYLE        # Success state
STATUS_FAILED_STYLE         # Failed state
STATUS_STEP_STYLE          # Step descriptions
STATUS_INFO_STYLE          # Information text
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
COLOR_BLACK        # Standard black
COLOR_RED          # Standard red
COLOR_GREEN        # Standard green
COLOR_YELLOW       # Standard yellow
COLOR_BLUE         # Standard blue
COLOR_MAGENTA      # Standard magenta
COLOR_CYAN         # Standard cyan
COLOR_WHITE        # Standard white
COLOR_GRAY         # Standard gray
```

### Custom Colors (RGB)

```bash
COLOR_SILVER      # #ABB2BF - Soft silver
COLOR_CHARCOAL    # #5C6370 - Dark gray
COLOR_SKY         # #61AFEF - Sky blue
COLOR_SAGE        # #B2C179 - Sage green
COLOR_CORAL       # #E06C75 - Coral red
COLOR_SAND        # #E5C07B - Sandy yellow
COLOR_SEAFOAM     # #8ABFB7 - Seafoam green
COLOR_LAVENDER    # #C678DD - Soft purple
```

### Bright Colors

All base and custom colors have bright variants:
```bash
COLOR_BRIGHT_RED
COLOR_BRIGHT_GREEN
# ... etc

COLOR_BRIGHT_SILVER
COLOR_BRIGHT_SKY
# ... etc
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

Pre-defined bold color combinations:
```bash
BOLD_RED, BOLD_GREEN, BOLD_YELLOW, BOLD_BLUE
BOLD_MAGENTA, BOLD_CYAN, BOLD_WHITE, BOLD_BRIGHT_WHITE
BOLD_SILVER, BOLD_CHARCOAL, BOLD_SKY, BOLD_SAGE
BOLD_CORAL, BOLD_SAND, BOLD_SEAFOAM, BOLD_LAVENDER
```

## Complete Custom Theme Example

Here's a complete "Cyberpunk" theme example:

```bash
"cyberpunk")
    # Cyberpunk theme - neon pink and blue
    
    # Global elements
    GLOBAL_TITLE_STYLE="$BOLD_BRIGHT_MAGENTA"
    GLOBAL_HINT_STYLE="$COLOR_BRIGHT_CYAN"
    
    # Catalog (Available Components)
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
    
    # Cart (Build Stack)
    CART_BORDER_COLOR="$COLOR_BRIGHT_CYAN"
    CART_TITLE_STYLE="$BOLD_BRIGHT_MAGENTA"
    CART_CATEGORY_STYLE="$COLOR_BRIGHT_YELLOW"
    CART_CURSOR_COLOR="$COLOR_BRIGHT_CYAN"
    CART_ITEM_STYLE="$COLOR_BRIGHT_WHITE"
    CART_BASE_CATEGORY_STYLE="$COLOR_BRIGHT_YELLOW"
    CART_BASE_ITEM_STYLE="$COLOR_WHITE"
    CART_REMOVE_HINT_STYLE="$COLOR_BRIGHT_RED"
    CART_COUNT_STYLE="$COLOR_BRIGHT_MAGENTA"
    
    # Instructions bar
    INSTRUCTION_KEY_STYLE="$COLOR_BRIGHT_CYAN"
    INSTRUCTION_TEXT_STYLE="$COLOR_WHITE"
    INSTRUCTION_ABORT_STYLE="$COLOR_BRIGHT_RED"
    
    # Summary screen
    SUMMARY_BORDER_COLOR="$COLOR_BRIGHT_MAGENTA"
    SUMMARY_TITLE_STYLE="$BOLD_BRIGHT_CYAN"
    SUMMARY_CHECKMARK_COLOR="$COLOR_BRIGHT_GREEN"
    SUMMARY_CATEGORY_STYLE="$COLOR_BRIGHT_YELLOW"
    
    # Deployment status
    STATUS_BORDER_COLOR="$COLOR_BRIGHT_CYAN"
    STATUS_TITLE_STYLE="$BOLD_BRIGHT_MAGENTA"
    STATUS_INITIAL_BULLET_COLOR="$COLOR_GRAY"
    STATUS_INITIAL_TEXT_COLOR="$COLOR_WHITE"
    STATUS_PENDING_BULLET_COLOR="$COLOR_BRIGHT_YELLOW"
    STATUS_PENDING_TEXT_COLOR="$COLOR_BRIGHT_YELLOW"
    STATUS_SUCCESS_BULLET_COLOR="$COLOR_BRIGHT_GREEN"
    STATUS_SUCCESS_TEXT_COLOR="$COLOR_BRIGHT_GREEN"
    STATUS_FAILED_BULLET_COLOR="$COLOR_BRIGHT_RED"
    STATUS_FAILED_TEXT_COLOR="$COLOR_BRIGHT_RED"
    STATUS_INFO_COLOR="$COLOR_BRIGHT_CYAN"
    
    # Logging styles
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
3. Navigate through all screens:
   - Component selection
   - Page navigation
   - Summary screen
   - Deployment progress
4. Test in different terminal emulators

## Theme Design Guidelines

1. **Contrast**: Ensure sufficient contrast between text and background
2. **Consistency**: Use consistent colors for similar elements
3. **Readability**: Test with both light and dark terminal backgrounds
4. **Accessibility**: Consider colorblind users (avoid red/green only distinctions)
5. **Purpose**: Use color to convey meaning:
   - Green = success/available
   - Red = error/failed
   - Yellow = warning/pending
   - Blue/Cyan = information/active

## Terminal Compatibility

The theme system uses ANSI escape codes that work in most modern terminals:
- iTerm2 (macOS) - Full support
- Terminal.app (macOS) - Full support
- GNOME Terminal (Linux) - Full support
- Konsole (Linux) - Full support
- Windows Terminal - Full support
- VS Code integrated terminal - Full support
- Alacritty - Full support
- tmux/screen - Full support with 256-color mode

### Enabling 256-Color Support

Some terminals need configuration:
```bash
# Check current setting
echo $TERM

# Enable 256 colors
export TERM=xterm-256color

# For tmux
echo "set -g default-terminal 'screen-256color'" >> ~/.tmux.conf
```

## Sharing Themes

To share your custom theme:

1. Extract your theme case from `load_theme()`
2. Document the color choices and inspiration
3. Include screenshots showing:
   - Component selection screen
   - Deployment progress
   - Both light and dark backgrounds
4. Submit a pull request to add it as a built-in theme

## Troubleshooting

### Colors Not Displaying Correctly

1. Verify terminal supports 256 colors:
   ```bash
   tput colors  # Should show 256
   ```

2. Test color capabilities:
   ```bash
   for i in {0..255}; do
       printf "\x1b[38;5;${i}mcolor%-5i\x1b[0m" $i
       if ! (( ($i + 1 ) % 8 )); then echo; fi
   done
   ```

3. Check terminal preferences for ANSI color support

### Theme Not Loading

1. Check environment variable:
   ```bash
   echo $AI_DEVKIT_THEME
   ```

2. Verify theme name matches exactly (case-sensitive)

3. Check for syntax errors:
   ```bash
   bash -n build-and-deploy.sh
   ```

### Poor Readability

1. Adjust terminal's base colors/profile
2. Try a different built-in theme
3. Modify specific problematic colors
4. Increase terminal font size
5. Adjust terminal background opacity

## Future Enhancements

Planned theme system improvements:
- Dynamic theme loading from external files
- Theme preview/selector in TUI
- Automatic light/dark detection
- Per-component color overrides
- Theme export/import functionality
