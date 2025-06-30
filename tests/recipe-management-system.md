# Recipe Management System - Development Specification

## Project Overview
Build a full-stack recipe management system with a GraphQL API backend in Rust and a Terminal User Interface (TUI) frontend in Python.

## Architecture Requirements

### Backend (Rust GraphQL API)
- **Framework**: Implement a GraphQL API using async-graphql with your choice of web framework
- **Architecture Pattern**: Repository pattern for data access layer
- **Persistence**: Flat file storage system using JSON
  - Implement async file I/O operations
  - Ensure thread-safe access for concurrent requests
- **Data Model**: Define clear schemas for Recipe entities including:
  - Recipe metadata (id, name, creation date, last modified)
  - Ingredients (with quantities and units)
  - Instructions (step-by-step)
  - Categories/tags
  - Preparation/cooking times
  - Servings

### Frontend (Python TUI)
- **Visual Design**: Create a visually appealing TUI with:
  - Consistent color scheme and theming
  - Clear visual hierarchy
  - Smooth transitions and responsive feedback
- **Navigation**: Dual navigation support:
  - Arrow keys for standard navigation
  - Vim-style keybindings (h/j/k/l, gg, G, etc.)
  - Clear on-screen navigation hints
- **Features**:
  - Recipe CRUD operations (Create, Read, Update, Delete)
  - List view with filtering and sorting capabilities
  - Detailed recipe view with formatted display
  - Search functionality
  - Input validation and error handling
- **API Integration**: GraphQL client implementation for backend communication

## Success Criteria
- Fully functional recipe management system
- Clean, maintainable code with proper documentation
- Comprehensive error handling
- Smooth user experience in the TUI
- Working test suite that validates functionality

---
Please acknowledge this specification and let me know if you need any clarification on the requirements or technical choices before we begin implementation.
