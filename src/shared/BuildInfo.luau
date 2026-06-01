--!strict
-- Identifies which published build this running server is.
-- `publish.sh` overwrites `sha` with the git short-SHA at publish time, so the game
-- can tell whether it's running the newest build (used by auto-reload to avoid
-- settling on a stale server — see Reload.luau).
--
-- Stays "dev" when running unpublished (Studio / local rojo builds).

return {
	sha = "dev",
	builtAt = "dev",
}
