# Prompt for Generating META- Documentation

I need you to create a META- documentation file for the following script/file. This META file will be used to provide context about the original file in future chat sessions without including the full implementation details.

**Original file name**: `build-and-deploy.sh`

**Instructions for the META file**:
1. Start with a header explaining this is a META documentation file that describes a file that exists in the project but is not shown
2. Capture the file's primary purpose and responsibilities
3. Document all key interfaces (functions, entry points, command-line arguments)
4. List important dependencies and what files/systems it interacts with
5. Describe key data structures or configuration formats it uses
6. Outline the high-level workflow/algorithm without implementation details
7. Note any side effects (files created, services started, etc.)
8. Include any critical assumptions or requirements
9. List environment variables or configuration it depends on
10. Mention error handling approach and failure modes
11. Keep implementation details minimal - focus on WHAT it does, not HOW

**Format the output as**:
- Use clear markdown formatting
- Include code blocks for command examples but not implementation
- Use bullet points for lists of features/capabilities
- Add a "Key Interactions" section showing how it relates to other parts of the system
- Name the file as `<original file path>/META-<original file without extension>.md`
- Create in new artifact window labeled with the full path of the new file
