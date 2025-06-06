# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Development Commands

```bash
# Setup development environment
asdf exec bundle exec bin/setup

# Install dependencies
asdf exec bundle install

# Run tests
asdf exec bundle exec rake spec
asdf exec bundle exec rake        # Default task runs specs

# Run a single test file
asdf exec bundle exec rspec spec/flashapi_spec.rb

# Open development console
asdf exec bundle exec bin/console

# Build gem
asdf exec bundle exec rake build

# Release gem (build, tag, push)
asdf exec bundle exec rake release
```

## High-Level Architecture

FlashAPI is an ultra-lightweight Ruby API framework prioritizing performance and modularity. Key architectural components:

1. **Application Router** (`lib/flashapi/application.rb`): Simple hash-based routing that matches URI and HTTP method to responder classes. Currently no parameter extraction or wildcards.

2. **Request Abstraction** (`lib/flashapi/base_request.rb`): Adapter-agnostic request representation allowing different server adapters to normalize requests.

3. **Responder Module** (`lib/flashapi/responder.rb`): Provides standardized JSON response format using Oj for fast serialization. Mixed into response handlers.

4. **Adapter Architecture** (`lib/flashapi/adapters/`): Pluggable server adapters design. Currently only stubs exist for EventMachine and Rack adapters - these need implementation.

## Current State

- Version 0.1.0 - early development stage
- Core routing and response abstractions implemented
- Server adapters are stubs only - need implementation before framework is usable
- Minimal test coverage
- Only production dependency: `oj` gem for JSON serialization

## Development Priorities

See TODO.md for comprehensive roadmap. Key immediate needs:
- Implement Rack adapter to make framework usable
- Add parameter parsing to router
- Increase test coverage
- Add usage examples

Performance targets: < 0.1ms overhead per request, > 50k req/s single core.

## Development Instructions for Claude Code

**IMPORTANT**: When implementing features or fixes, you MUST:

1. **Follow TODO.md roadmap**: All development should align with the priorities and specifications outlined in TODO.md
2. **Check off completed items**: After successfully implementing any feature from TODO.md, mark the corresponding checkbox as `[x]` to track progress
3. **Maintain architectural principles**: Ensure all changes preserve the ultra-lightweight, modular, and performance-first approach
4. **Run tests after changes**: Always execute `asdf exec bundle exec rake spec` to verify implementations don't break existing functionality
5. **Update documentation**: When adding new features, update relevant sections in this file and ensure examples remain current

Before starting any implementation, review the relevant section in TODO.md to understand the full scope and requirements.