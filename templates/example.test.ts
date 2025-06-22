import { test, expect } from "@microsoft/tui-test";

test.describe("Example TUI Tests", () => {
  test("basic terminal interaction", async ({ terminal }) => {
    // Write to terminal
    terminal.write("echo 'Hello, TUI Test!'");
    terminal.submit(); // Press Enter
    
    // Wait for output and assert
    await expect(terminal.getByText("Hello, TUI Test!")).toBeVisible();
  });
  
  test("test with specific shell", async ({ terminal }) => {
    // Configure to use bash
    test.use({ shell: "bash" });
    
    terminal.write("pwd");
    terminal.submit();
    
    await expect(terminal.getByText("/home/devuser")).toBeVisible();
  });
  
  test("capture terminal snapshot", async ({ terminal }) => {
    terminal.write("ls -la");
    terminal.submit();
    
    // Wait for command to complete
    await terminal.waitForRender();
    
    // Take snapshot for visual regression testing
    await expect(terminal).toMatchSnapshot();
  });
  
  test("test CLI application", async ({ terminal }) => {
    // Start your application
    test.use({ program: { file: "python", args: ["app.py"] } });
    
    // Wait for app to start
    await expect(terminal.getByText("Welcome")).toBeVisible();
    
    // Navigate menu
    terminal.sendNavigationKey("down");
    terminal.sendNavigationKey("enter");
    
    // Assert state
    await expect(terminal.getByText("Selected:")).toBeVisible();
  });
});
