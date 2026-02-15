# ⚡ TrueSignal

A lightweight, strongly-typed Signal implementation for Roblox development. This utility allows for event-driven programming with support for generics, built-in cleanup handling, and a global signal registry.

## 📃 Features

* **Type Safe:** Full Luau generic support (`<A...>`) for strict typing of signal arguments.
* **Built-in Cleanup:** `connect` and `once` accept a secondary `cleanup` callback, allowing you to bind destructors directly to connections.
* **Global Registry:** A built-in store system (`store`/`getStored`) to easily share signals across different scripts without requiring a central module loader.
* **Async Utilities:** Includes `wait` and `waitUntil` (with timeout) for coroutine management.
* **Roblox Optimized:** Utilizes the `task` library (`task.spawn`, `task.delay`, `task.cancel`) for efficient scheduling.

## 📦 Installation
Download the .rbxm file from the releases!
https://github.com/x6nny/TrueSignal/releases

## 🔧Usage

### Basic Example

```lua
local Signal = require(path.to.Signal)

-- Create a signal that accepts a string and a number
local onMessage = Signal.new() :: Signal.Signal<string, number>

-- Connect a listener
local disconnect = onMessage:connect(function(msg, count)
    print("Received:", msg, count)
end)

-- Fire the signal
onMessage:fire("Hello World", 42)

-- Disconnect later
disconnect()

```

### using `waitUntil` (Timeout)

Yields the current thread until the signal fires or the timeout is reached.

```lua
local mySignal = Signal.new()

task.spawn(function()
    task.wait(2)
    mySignal:fire("Success!")
end)

-- Wait up to 5 seconds
local result = mySignal:waitUntil(5)

if result then
    print("Signal fired:", result)
else
    print("Timed out!")
end

```

## API Reference

### Constructor

#### `Signal.new<A...>()`

Creates a new Signal object.

* **Returns:** `Signal<A...>`

---

### Methods

#### `:connect(listener, cleanup?)`

Connects a function to the signal.

* **listener:** `(A...) -> ()` - The function to call when fired.
* **cleanup:** `() -> ()?` - (Optional) A function to run when this specific connection is disconnected or the signal is cleaned up.
* **Returns:** `() -> ()` - A function that, when called, disconnects the listener.

#### `:once(listener, cleanup?)`

Connects a function that will only run the next time the signal is fired, then disconnects automatically.

* **listener:** `(A...) -> ()`
* **cleanup:** `() -> ()?`
* **Returns:** `() -> ()` - A function to disconnect early.

#### `:fire(...)`

Fires the signal, invoking all connected listeners with the provided arguments.

* **Args:** `A...`

#### `:wait()`

Yields the current thread until the signal is fired.

* **Returns:** `A...` (The arguments passed to `:fire`)

#### `:waitUntil(timeout)`

Yields the current thread until the signal is fired OR the timeout is reached.

* **timeout:** `number` - Time in seconds to wait.
* **Returns:** `A...` (The arguments passed to `:fire`) or `nil` if timed out.

#### `:cleanUp()`

Disconnects all listeners and runs the `cleanup` callback for every connection (if one was provided during connection).

---

### Global Store System

This module includes a registry to store signals by name, making them accessible from other scripts.

#### `:store(name, overwrite?)`

Saves the current signal into the global registry.

* **name:** `string` - The key to store the signal under.
* **overwrite:** `boolean?` - If false, it will not overwrite an existing signal with the same name.

#### `:unstore()`

Removes the signal from the global registry.

#### `Signal.getStored(name)`

Static function to retrieve a signal from the registry.

* **name:** `string`
* **Returns:** `Signal<A...>?`

**Example:**

```lua
-- Script A
local levelUp = Signal.new()
levelUp:store("LevelUpEvent")

-- Script B
local Signal = require(path.to.Signal)
local levelUp = Signal.getStored("LevelUpEvent")

if levelUp then
    levelUp:connect(function()
        print("Level up detected in Script B!")
    end)
end

```
