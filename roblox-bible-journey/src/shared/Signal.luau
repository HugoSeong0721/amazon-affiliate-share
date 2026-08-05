--!strict
-- Minimal signal so the prototype has zero external dependencies.

export type Connection = { disconnect: (self: Connection) -> () }

local Signal = {}
Signal.__index = Signal

export type Signal = typeof(setmetatable(
	{} :: {
		_handlers: { (...any) -> () },
	},
	Signal
))

function Signal.new(): Signal
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal.connect(self: Signal, handler: (...any) -> ()): Connection
	table.insert(self._handlers, handler)

	local connection = {}
	function connection.disconnect()
		local index = table.find(self._handlers, handler)
		if index then
			table.remove(self._handlers, index)
		end
	end
	return connection
end

function Signal.fire(self: Signal, ...: any)
	-- Copy first: a handler may disconnect during the loop.
	local handlers = table.clone(self._handlers)
	for _, handler in handlers do
		task.spawn(handler, ...)
	end
end

function Signal.destroy(self: Signal)
	table.clear(self._handlers)
end

return Signal
