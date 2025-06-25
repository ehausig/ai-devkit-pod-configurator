# Theme Customization Guide

The AI DevKit Pod Configurator features a sophisticated theming system for the Terminal User Interface (TUI) that allows you to customize colors and styles to match your preferences.

## Table of Contents

- [Available Themes](#available-themes)
- [Using Themes](#using-themes)
- [Theme Structure](#theme-structure)
- [Creating Custom Themes](#creating-custom-themes)
- [Color Reference](#color-reference)
- [Theme Components](#theme-components)
- [Best Practices](#best-practices)

## Available Themes

The build script includes several built-in themes:

### 1. **Default Theme**
- Professional color scheme with cyan, blue, and sage green accents
- High contrast for readability
- Suitable for both light and dark terminals

### 2. **Dark Theme**
- Softer colors optimized for dark terminals
- Reduced eye strain for extended use
- Muted color palette

### 3. **Matrix Theme**
- Classic green-on-black terminal aesthetic
- All UI elements in various shades of green
- Perfect for that hacker vibe

### 4. **Ocean Theme**
- Blues and cyans inspired by the sea
- Calming color palette
- Good for extended coding sessions

### 5. **Minimal Theme**
- Mostly white and gray
- Reduces visual clutter
- Focus on content over style

### 6. **Neon Theme**
- High contrast with bright, vibrant colors
- Eye-catching design
- Great for demonstrations

## Using Themes

### Setting a Theme

You can set a theme using the `AI_DEVKIT_THEME` environment variable:

```bash
# Use a specific theme for one run
AI_DEVKIT_THEME=matrix ./build-and-deploy.sh

# Export for the session
export AI_DEVKIT_THEME=ocean
./build-and-deploy.sh

# Make it permanent (add to ~/.bashrc or ~/.zshrc)
echo 'export AI_DEVKIT_THEME=dark' >> ~/.bashrc
```

### Available Theme Names

- `default` (or unset)
- `dark`
- `matrix`
- `ocean`
- `minimal`
- `neon`

## Theme Structure

Themes are defined in the `build-and-deploy.sh` script within the `load_theme()` function. Each theme sets various color and style variables for different UI components.

### Color Variable Categories

1. **Base Colors** - Fundamental terminal colors
2. **Custom Colors** - Extended color palette
3. **UI Component Styles** - Specific styles for each UI element

## Creating Custom Themes

To add a new theme, modify the `load_theme()` function in `build-and-deploy.sh`:

```bash
# In the load_theme() function, add a new case:
"mytheme")
    # Set your custom colors
    GLOBAL_TITLE_STYLE="$BOLD_MAGENTA"
    CATALOG_BORDER_COLOR="$COLOR_BRIGHT_MAGENTA"
    CATALOG_CURSOR_COLOR="$COLOR_BRIGHT_YELLOW"
    # ... set all other variables
    ;;
```

### Complete Theme Template

Here's a template for creating a complete custom theme:

```bash
"custom")
    # Global Elements
    GLOBAL_TITLE_STYLE="$BOLD_CYAN"
    GLOBAL_HINT_STYLE="$COLOR_YELLOW"
    
    # Instructions Bar
    INSTRUCTION_KEY_STYLE="$BOLD_WHITE"
    INSTRUCTION_TEXT_STYLE="$COLOR_GRAY"
    INSTRUCTION_ABORT_STYLE="$COLOR_RED"
    
    # Catalog Box (Available Components)
    CATALOG_BORDER_COLOR="$COLOR_BRIGHT_CHARCOAL"
    CATALOG_TITLE_STYLE="$BOLD_WHITE"
    CATALOG_CATEGORY_STYLE="$COLOR_SEAFOAM"
    CATALOG_CURSOR_COLOR="$COLOR_BRIGHT_BLUE"
    CATALOG_ITEM_SELECTED_STYLE="$COLOR_BRIGHT_SAGE"
    CATALOG_ITEM_AVAILABLE_STYLE="$COLOR_BRIGHT_WHITE"
    CATALOG_ITEM_DISABLED_STYLE="$COLOR_GRAY"
    CATALOG_STATUS_IN_STACK_STYLE="$COLOR_BRIGHT_SAGE"
    CATALOG_STATUS_REQUIRED_STYLE="$COLOR_SAND"
    CATALOG_PAGE_INDICATOR_STYLE="$COLOR_SAND"
    CATALOG_ICON_SELECTED_COLOR="$COLOR_BRIGHT_SAGE"
    CATALOG_ICON_AVAILABLE_COLOR="$STYLE_RESET"
    CATALOG_ICON_DISABLED_COLOR="$COLOR_GRAY"
    CATALOG_ICON_WARNING_COLOR="$COLOR_MAGENTA"
    
    # Cart Box (Build Stack)
    CART_BORDER_COLOR="$COLOR_BRIGHT_CHARCOAL"
    CART_TITLE_STYLE="$BOLD_WHITE"
    CART_CATEGORY_STYLE="$COLOR_BRIGHT_SEAFOAM"
    CART_CURSOR_COLOR="$COLOR_BRIGHT_BLUE"
    CART_ITEM_STYLE="$COLOR_BRIGHT_SAGE"
    CART_BASE_CATEGORY_STYLE="$COLOR_SEAFOAM"
    CART_BASE_ITEM_STYLE="$COLOR_SILVER"
    CART_REMOVE_HINT_STYLE="$COLOR_WHITE"
    CART_COUNT_STYLE="$COLOR_SAND"
    
    # Summary Screen
    SUMMARY_BORDER_COLOR="$COLOR_SAGE"
    SUMMARY_TITLE_STYLE="$BOLD_WHITE"
    SUMMARY_CATEGORY_STYLE="$COLOR_BRIGHT_SEAFOAM"
    SUMMARY_CHECKMARK_COLOR="$COLOR_BRIGHT_SAGE"
    
    # Deployment Status
    STATUS_BORDER_COLOR="$COLOR_BRIGHT_CHARCOAL"
    STATUS_TITLE_STYLE="$BOLD_WHITE"
    STATUS_PENDING_STYLE="$COLOR_SAND"
    STATUS_RUNNING_STYLE="$COLOR_BRIGHT_SKY"
    STATUS_SUCCESS_STYLE="$COLOR_BRIGHT_SAGE"
    STATUS_FAILED_STYLE="$COLOR_BRIGHT_CORAL"
    STATUS_STEP_STYLE="$COLOR_SILVER"
    STATUS_INFO_STYLE="$COLOR_BRIGHT_CYAN"
    
    # Logging
    LOG_ERROR_STYLE="$COLOR_RED"
    LOG_SUCCESS_STYLE="$COLOR_GREEN"
    LOG_WARNING_STYLE="$BOLD_YELLOW"
    LOG_INFO_STYLE="$COLOR_BLUE"
    LOG_DEFAULT_STYLE="$COLOR_YELLOW"
    ;;
```

## Color Reference

### Base Terminal Colors

```bash
COLOR_BLACK='\033[0;30m'
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'
COLOR_BLUE='\033[0;34m'
COLOR_MAGENTA='\033[0;35m'
COLOR_CYAN='\033[0;36m'
COLOR_WHITE='\033[0;37m'
COLOR_GRAY='\033[0;90m'
```

### Bright Colors

```bash
COLOR_BRIGHT_RED='\033[0;91m'
COLOR_BRIGHT_GREEN='\033[0;92m'
COLOR_BRIGHT_YELLOW='\033[0;93m'
COLOR_BRIGHT_BLUE='\033[0;94m'
COLOR_BRIGHT_MAGENTA='\033[0;95m'
COLOR_BRIGHT_CYAN='\033[0;96m'
COLOR_BRIGHT_WHITE='\033[0;97m'
```

### Custom Extended Colors

```bash
COLOR_SILVER='\033[38;2;171;178;191m'       # #ABB2BF
COLOR_CHARCOAL='\033[38;2;92;99;112m'       # #5C6370
COLOR_SKY='\033[38;2;97;175;239m'           # #61AFEF
COLOR_SAGE='\033[38;2;178;193;121m'         # #B2C179
COLOR_CORAL='\033[38;2;224;108;117m'        # #E06C75
COLOR_SAND='\033[38;2;229;192;123m'         # #E5C07B
COLOR_SEAFOAM='\033[38;2;138;191;183m'      # #8ABFB7
COLOR_LAVENDER='\033[38;2;198;120;221m'     # #C678DD
```

### Style Modifiers

```bash
STYLE_BOLD='\033[1m'
STYLE_DIM='\033[2m'
STYLE_ITALIC='\033[3m'
STYLE_UNDERLINE='\033[4m'
STYLE_BLINK='\033[5m'
STYLE_REVERSE='\033[7m'
STYLE_RESET='\033[0m'
```

## Theme Components

### 1. Title Bar

The gradient title uses multiple colors:

```bash
# Example from the default theme
local gradient_colors=("$COLOR_CYAN" "$COLOR_BLUE" "$COLOR_LAVENDER" "$COLOR_MAGENTA")
```

### 2. Component Catalog

- **Border**: Frame around the available components
- **Categories**: Section headers (Languages, Build Tools, etc.)
- **Items**: Individual components with various states
- **Icons**: Selection indicators (✓, ○, etc.)

### 3. Build Stack (Cart)

- **Border**: Frame around selected components
- **Base Items**: Always-included components
- **Selected Items**: User-selected components
- **Counter**: Shows number of selected items

### 4. Status Display

- **Animations**: Spinning indicators for running tasks
- **Status Colors**: Different colors for pending, running, success, failed
- **Messages**: Additional information for each step

### 5. Instructions Bar

- **Key Hints**: Keyboard shortcuts in highlighted style
- **Action Text**: Description of what each key does

## Best Practices

### 1. Contrast

Ensure sufficient contrast between:
- Text and background
- Selected and unselected items
- Different UI sections

### 2. Consistency

- Use the same color for similar elements
- Maintain a cohesive color palette
- Don't use too many different colors

### 3. Accessibility

- Consider colorblind users
- Test on different terminal backgrounds
- Ensure text remains readable

### 4. Terminal Compatibility

- Test on multiple terminal emulators
- Some terminals may not support all colors
- Provide fallbacks for limited color support

### 5. Color Psychology

- **Green**: Success, completion, positive actions
- **Red**: Errors, warnings, stop actions
- **Blue**: Information, navigation, neutral elements
- **Yellow**: Warnings, attention, hints
- **Gray**: Disabled, unavailable, background elements

## Advanced Theming

### RGB Color Definition

You can define custom RGB colors:

```bash
# Define a custom color using RGB values
COLOR_CUSTOM='\033[38;2;R;G;Bm'  # Replace R, G, B with values 0-255

# Example: Purple (128, 0, 128)
COLOR_PURPLE='\033[38;2;128;0;128m'
```

### Background Colors

To set background colors:

```bash
# Background color format
BG_COLOR='\033[48;2;R;G;Bm'

# Example: Blue background
BG_BLUE='\033[48;2;0;0;255m'
```

### Combining Styles

You can combine multiple styles:

```bash
# Bold red text on blue background
STYLE_COMBO="${STYLE_BOLD}${COLOR_RED}${BG_BLUE}"
```

## Testing Your Theme

1. **Quick Test**: Run the build script with your theme
   ```bash
   AI_DEVKIT_THEME=mytheme ./build-and-deploy.sh
   ```

2. **Visual Check**: Navigate through all UI elements:
   - Browse component pages
   - Select/deselect items
   - Switch between catalog and cart
   - View the build process

3. **Different Terminals**: Test in various terminal emulators:
   - Terminal.app (macOS)
   - iTerm2
   - VS Code integrated terminal
   - tmux/screen sessions

4. **Background Colors**: Test with both light and dark terminal backgrounds

## Contributing Themes

To contribute a new theme:

1. Create a well-tested theme following the template
2. Ensure it works on common terminal emulators
3. Document any special requirements
4. Submit a pull request with:
   - Theme code in `build-and-deploy.sh`
   - Screenshot showing the theme
   - Description of the theme's design philosophy

## Troubleshooting

### Colors Not Displaying

- Check if your terminal supports 24-bit color
- Try a simpler theme like `minimal`
- Verify the `TERM` environment variable is set correctly

### Text Unreadable

- Adjust contrast between foreground and background
- Test on both light and dark terminal backgrounds
- Use the `STYLE_BOLD` modifier for better visibility

### Theme Not Loading

- Verify the theme name is spelled correctly
- Check that the theme case matches in `load_theme()`
- Ensure no syntax errors in theme definition
