---
description: Switch to a different development persona (architect, developer, qa, reviewer, merger)
---

# Switch Development Persona

Switch to a different persona to handle specific phases of development.

## Usage

```
/switch-persona [persona]
```

Where `[persona]` is one of:
- `architect` - System design and planning
- `developer` - Implementation and coding
- `qa` - Testing and quality assurance
- `reviewer` - Code review
- `merger` - Integration and deployment

## Instructions

1. Execute the initialization script for the requested persona
2. The script will:
   - Log the persona switch
   - Load relevant context from journal
   - Show pending work
   - Display next steps
   - **Display the full persona protocol inline**
3. Read the displayed protocol carefully - it defines your responsibilities
4. Begin work according to the protocol

## Example

To switch to developer persona:
```bash
persona-developer-init.sh
```

This will initialize the DEVELOPER persona and display the complete DEVELOPER protocol in the terminal for you to follow.
