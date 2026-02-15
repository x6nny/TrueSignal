--[=[
	A lightweight Signal implementation for handling custom events.
	@class Signal
]=]

type listener<A...> = (A...) -> ()
type cleanup = () -> ()?

--[=[
	@interface SignalData
	@within Signal
	@field connections { { listener: listener, cleanup: cleanup } }
]=]
type signal<A...> = {
	connections: {
		{
			listener: listener<A...>,
			cleanup: cleanup,
		}
	},
}

--[=[
	@interface SignalClass
	@within Signal
	@field store (signal: Signal, name: string, overwrite: boolean?) -> ()
	@field unstore (signal: Signal) -> ()
	@field fire (signal: Signal, ...any) -> ()
	@field connect (signal: Signal, listener: function, cleanup: function?) -> () -> ()
	@field once (signal: Signal, listener: function, cleanup: function?) -> () -> ()
	@field wait (signal: Signal) -> ...any
	@field waitUntil (signal: Signal, timeout: number) -> ...any
	@field cleanUp (signal: Signal) -> ()
]=]
type class<A...> = {
	store: (signal: signal<A...>, name: string, overwrite: boolean?) -> (),
	unstore: (signal: signal<A...>) -> (),
	fire: (signal: signal<A...>, A...) -> (),
	connect: (signal: signal<A...>, listener: listener<A...>, cleanup: cleanup) -> () -> (),
	once: (signal: signal<A...>, listener: listener<A...>, cleanup: cleanup) -> () -> (),
	wait: (signal: signal<A...>) -> A...,
	waitUntil: (signal: signal<A...>, timeout: number) -> A...,
	cleanUp: (signal: signal<A...>) -> (),
}

export type Signal<A...> = signal<A...> & class<A...>

local stored = { }

--[=[
	Stores a signal in a global registry by name.
	@within Signal
	@param signal Signal -- The signal to store.
	@param name string -- The name to register the signal under.
	@param overwrite? boolean -- Whether to overwrite an existing signal with the same name.
]=]
local function store<A...>(signal: signal<A...>, name: string, overwrite: boolean?)
	if stored[name] ~= nil and (overwrite == nil or overwrite == false) then
		return
	end

	stored[name] = signal
end

--[=[
	Removes a signal from the global registry.
	@within Signal
	@param signal Signal -- The signal to remove.
]=]
local function unstore<A...>(signal: signal<A...>)
	local foundName: string?
	for name, sig in pairs(stored) do
		if sig == signal then
			foundName = name
			break
		end
	end

	if foundName then
		stored[foundName] = nil
	end
end

--[=[
	Retrieves a stored signal by name.
	@within Signal
	@param name string -- The name of the signal to retrieve.
	@return Signal -- The stored signal, or nil if not found.
]=]
local function getStored<A...>(name: string): Signal<A...>
	return stored[name]
end

--[=[
	Connects a listener to the signal.
	@method connect
	@within Signal
	@param signal Signal -- The signal instance.
	@param listener function -- The callback function to execute when the signal is fired.
	@param cleanup? function -- An optional cleanup function to run when the connection is disconnected.
	@return function -- A function that, when called, disconnects the listener.
]=]
local function connect<A...>(signal: signal<A...>, listener: listener<A...>, cleanup: cleanup): () -> ()
	local connection = {
		listener = listener,
		cleanup = cleanup
	}

	table.insert(signal.connections, connection)

	return function()
		local index = table.find(signal.connections, connection)
		if index then
			table.remove(signal.connections, index)
		end

		if cleanup then
			task.spawn(cleanup)
		end
	end
end

--[=[
	Connects a listener that will only run once.
	@method once
	@within Signal
	@param signal Signal -- The signal instance.
	@param listener function -- The callback function.
	@param cleanup? function -- Optional cleanup function.
	@return function -- A function to disconnect the listener before it fires.
]=]
local function once<A...>(signal: signal<A...>, listener: listener<A...>, cleanup: cleanup): () -> ()
	local connection: () -> ()?
	connection = connect(signal, function(...)
		task.spawn(listener, ...)

		if connection then
			connection()
			connection = nil
		end
	end, cleanup)

	return function()
		if connection then
			connection()
			connection = nil
		end
	end
end

--[=[
	Fires the signal, executing all connected listeners with the provided arguments.
	@method fire
	@within Signal
	@param signal Signal -- The signal instance.
	@param ... any -- The arguments to pass to the listeners.
]=]
local function fire<A...>(signal: signal<A...>, ... : A...)
	for i = 1, #signal.connections do
		local connection = signal.connections[i]
		task.spawn(connection.listener, ...)
	end
end

--[=[
	Yields the current thread until the signal is fired.
	@method wait
	@within Signal
	@param signal Signal -- The signal instance.
	@return ...any -- The arguments passed when the signal was fired.
]=]
local function wait<A...>(signal: signal<A...>): A...
	local running = coroutine.running()

	local connection
	connection = once(signal, function(...)
		coroutine.resume(running, ...)
	end, function()
		coroutine.resume(running)
	end)

	return coroutine.yield()
end

--[=[
	Yields until the signal is fired or the timeout is reached.
	@method waitUntil
	@within Signal
	@param signal Signal -- The signal instance.
	@param timeout number -- The maximum time to wait in seconds.
	@return ...any -- The arguments from the signal, or nil if timed out.
]=]
local function waitUntil<A...>(signal: signal<A...>, timeout : number): A...
	local running = coroutine.running()

	local connection: () -> ()?
	local thread: thread?
	connection = once(signal, function(...)
		coroutine.resume(running, ...)
	end, function()
		if thread then
			task.cancel(thread)
		end
		coroutine.resume(running)
	end)

	thread = task.delay(timeout, function()
		thread = nil
		if connection ~= nil then
			connection()
			connection = nil
		end
	end)

	return coroutine.yield()
end

--[=[
	Disconnects all listeners and runs their cleanup functions.
	@method cleanUp
	@within Signal
	@param signal Signal -- The signal instance.
]=]
local function cleanUp<A...>(signal: signal<A...>)
	for i, v in signal.connections do
		if v.cleanup then
			task.spawn(v.cleanup)
		end
	end

	table.clear(signal.connections)
end

--[=[
	Creates a new Signal instance.
	@within Signal
	@return Signal -- The new signal object.
]=]
local function new<A...>(): Signal<A...>
	return {
		connections = { },

		store = store,
		unstore = unstore,
		fire = fire,
		connect = connect,
		once = once,
		wait = wait,
		waitUntil = waitUntil,
		cleanUp = cleanUp,
	} :: any
end

return {
	new = new,
	connect = connect,
	fire = fire,
	once = once,
	wait = wait,
	waitUntil = waitUntil,
	cleanUp = cleanUp,
	store = store,
	unstore = unstore,
	getStored = getStored,
}