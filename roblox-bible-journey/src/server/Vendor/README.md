# Vendor

Drop `ProfileStore.luau` (MadStudioRoblox) here to switch persistence on.

`ProgressService` looks for `ServerScriptService.Server.Vendor.ProfileStore` at
startup. If it is missing, the game runs on `MemoryBackend` and warns on every
boot — progress will not survive a server restart, so do not ship in that state.

`ProfileStoreBackend.luau` targets the ProfileStore 1.x API
(`:StartSessionAsync` / `:EndSession` / `.OnSessionEnd`). If you install the older
ProfileService instead, three marked lines in that file need adapting.
