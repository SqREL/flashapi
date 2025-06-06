# FlashAPI Examples

This directory contains example applications demonstrating the modernized FlashAPI framework with Ruby 3.2+ features.

## Running the Example

### Using the built-in server

```bash
# Using Rack adapter (default)
ruby app.rb

# Using EventMachine adapter for high performance
ruby app.rb eventmachine 3000

# Custom port
ruby app.rb rack 8080
```

### Using Rackup

```bash
rackup config.ru -p 3000
```

### Using other Rack servers

```bash
# Puma
puma config.ru

# Unicorn
unicorn config.ru

# Thin
thin start -R config.ru
```

## Example Endpoints

The example application includes a simple user management API:

- `GET /` - Welcome message
- `GET /users` - List all users
- `POST /users` - Create a new user (requires name and email in JSON body)
- `GET /users/:id` - Get a specific user
- `PUT /users/:id` - Update a user (name or email in JSON body)
- `DELETE /users/:id` - Delete a user

## Testing with curl

```bash
# Home endpoint
curl http://localhost:3000/

# List users
curl http://localhost:3000/users

# Create a user
curl -X POST http://localhost:3000/users \
  -H "Content-Type: application/json" \
  -d '{"name": "Charlie", "email": "charlie@example.com"}'

# Get a user
curl http://localhost:3000/users/1

# Update a user
curl -X PUT http://localhost:3000/users/1 \
  -H "Content-Type: application/json" \
  -d '{"name": "Alice Updated"}'

# Delete a user
curl -X DELETE http://localhost:3000/users/1
```

## Modern Ruby Features Demonstrated

1. **Data Classes** - BaseRequest uses Ruby 3.2's Data.define
2. **Pattern Matching** - Request routing and parameter validation
3. **Endless Methods** - Concise method definitions throughout
4. **Hash Shorthand** - Modern hash syntax with matching variable names
5. **Numbered Parameters** - Used in block iterations
6. **Frozen String Literals** - Performance optimization in all files

## Architecture

The example demonstrates:

- Clean separation of concerns with responder classes
- Type-safe request handling with Data classes
- Pattern matching for elegant request routing
- Built-in error handling and status responses
- Support for multiple server adapters