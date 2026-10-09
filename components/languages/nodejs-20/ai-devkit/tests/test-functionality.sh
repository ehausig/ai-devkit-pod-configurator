#!/bin/bash
# Test Node.js functionality
set -e

echo "Testing Node.js functionality..."

# Test basic JavaScript features
node -e "
console.log('Testing core Node.js features...');

// Test ES6+ features
const arr = [1, 2, 3];
const doubled = arr.map(x => x * 2);
console.log('✅ ES6 arrow functions working');

// Test async/await
(async () => {
    const result = await Promise.resolve('async works');
    console.log('✅ Async/await:', result);
})();

// Test template literals
const name = 'Node.js 20';
console.log(\`✅ Template literals: Testing \${name}\`);

// Test destructuring
const { version } = process;
console.log('✅ Destructuring working, Node version:', version);
" || {
    echo "❌ Basic Node.js features not working"
    exit 1
}

# Test built-in modules
node -e "
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const http = require('http');

console.log('✅ Core modules loading correctly');

// Test file system
const testFile = '/tmp/node-test-' + Date.now() + '.txt';
fs.writeFileSync(testFile, 'test');
const content = fs.readFileSync(testFile, 'utf8');
fs.unlinkSync(testFile);
console.log('✅ File system operations working');

// Test crypto
const hash = crypto.createHash('sha256').update('test').digest('hex');
console.log('✅ Crypto working, hash:', hash.substring(0, 10) + '...');
" || {
    echo "❌ Node.js built-in modules not working"
    exit 1
}

echo "✅ All Node.js functionality tests passed"