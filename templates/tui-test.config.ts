import { defineConfig } from "@microsoft/tui-test";

export default defineConfig({
  // Number of retries for flaky tests
  retries: 3,
  // Enable trace capture for debugging
  trace: true,
  // Test timeout in milliseconds
  timeout: 30000,
  // Directory for trace files
  outputDir: "tui-traces",
  // Run tests in parallel
  parallel: true,
  // Number of parallel workers
  workers: 4
});
