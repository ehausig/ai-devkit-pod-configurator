# Prompt Templates

This directory contains prompt templates that users can submit to Large Language Models (LLMs) like Claude, ChatGPT, or other AI assistants when working with the AI DevKit Pod Configurator project.

## Available Templates

### meta-file-generator.md
A template for generating META documentation files that describe scripts without including full implementation details. This is useful for:
- Reducing context size in LLM conversations
- Documenting script interfaces and responsibilities
- Creating high-level overviews of complex files

## Usage

1. **Copy the template content** from the desired `.md` file
2. **Replace placeholders** with your specific information:
   - File names
   - Specific requirements
   - Context details
3. **Submit to your LLM** along with the source file you want documented

## Example Workflow

To generate META documentation for a script:

```bash
# 1. View the template
cat prompts/meta-file-generator.md

# 2. Copy the template content to your LLM conversation

# 3. Replace the placeholder with your script name
#    e.g., change "build-and-deploy.sh" to "your-script.sh"

# 4. Submit to the LLM along with your script content
```

## Purpose of META Files

META files serve to:
- **Reduce token usage** - Describe interfaces without implementation
- **Maintain context** - Keep awareness of file purposes across sessions
- **Document architecture** - Capture high-level design without code details
- **Speed up conversations** - LLMs can reference capabilities without parsing full files

## Creating New Prompt Templates

When adding new templates:
1. Use clear markdown formatting
2. Include placeholder sections marked with `<brackets>` or **bold**
3. Provide clear instructions within the template
4. Add usage examples where helpful
5. Update this README with the new template description

## Best Practices

- **Be specific** in your prompts about what you want
- **Include context** about your project when relevant
- **Review outputs** before using generated documentation
- **Iterate** on prompts to improve results

## Related Documentation

- For LLM context documentation, see [`/llm`](../llm/)
- For component documentation, see [`/docs/components.md`](../docs/components.md)
- For architecture overview, see [`/docs/architecture.md`](../docs/architecture.md)