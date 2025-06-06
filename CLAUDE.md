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