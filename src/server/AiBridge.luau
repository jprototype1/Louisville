--!strict
-- Bridge from the live game to the OpenACP daemon (the thing that runs the AI
-- builder). The kid types a request in-game → this POSTs it to OpenACP over the
-- public Cloudflare tunnel → Claude edits the code and publishes → the game
-- auto-reloads onto the new build (see AiPrompt.luau + Reload.luau).
--
-- Roblox game servers run in Roblox's cloud and CANNOT reach the operator's Mac
-- directly, so we go through the OpenACP tunnel URL (public, but auth-gated).
--
-- ── SETUP (operator, one-time) ────────────────────────────────────────────────
--   1. Enable HTTP requests for the game:
--        Game Settings → Security → "Allow HTTP Requests" = ON
--   2. Store a durable OpenACP Bearer token as a Roblox Secret so it is NEVER in code:
--        Creator Dashboard → your experience → Secrets → add key `openacp_token`
--        Token options (both verified to work over the tunnel):
--          • the daemon's static api-secret (.openacp/api-secret) — never expires, but
--            it is the MASTER admin secret (full daemon control), so treat it carefully
--          • or a long-lived admin token: `openacp remote --role admin --expire 8760h`,
--            then redeem its one-time code once to get the bearer (revocable + expiring)
--      (Falls back to localToken below only for Studio testing — leave it blank in
--       commits; the token would otherwise ship inside the published game.)
--   3. Confirm CONFIG.baseUrl matches your tunnel (openacp remote prints it).

local HttpService = game:GetService("HttpService")

local CONFIG = {
	-- Public OpenACP tunnel base (NOT secret — just the hostname). From `openacp remote`.
	baseUrl = "https://tunnel-ed6ee4e1.openacp.ai",
	-- Which agent + workspace OpenACP should spin the session up in.
	apiBase = "/api/v1/sessions",
	agent = "claude",
	workspace = "/Users/gnijor/roblox/brookhaven",
	-- Progress relay (scripts/ai-progress-relay.mjs) — serves pollable transcript lines
	-- since OpenACP only streams them over SSE, which Roblox can't consume. This is a
	-- cloudflared *quick* tunnel URL: it changes whenever the relay tunnel restarts.
	progressBaseUrl = "https://duties-familiar-round-safari.trycloudflare.com",
	-- Roblox Secret key holding the Bearer token (preferred — keeps it out of code).
	secretKey = "openacp_token",
	-- Studio/local-only fallback. KEEP BLANK in commits — anything here ships live.
	localToken = "",
}

-- API contract verified live against the OpenACP daemon (2026-06-01):
--   * routes live under /api/v1/sessions
--   * auth is an `Authorization: Bearer <token>` header. The ?code= from `openacp
--     remote` is a one-time 30-min redemption code, NOT the token — but the daemon's
--     static api-secret works directly as a durable Bearer (verified over the tunnel).
--   * responses are wrapped: { success = bool, data = {...} }

local AiBridge = {}

-- The Authorization header value ("Bearer <token>"). Uses a Roblox Secret when set
-- (so the token never appears in readable code), else the local fallback.
local function authHeader(): (string | Secret)?
	local ok, secret = pcall(function()
		return HttpService:GetSecret(CONFIG.secretKey)
	end)
	if ok and secret then
		return secret:AddPrefix("Bearer ")
	end
	if CONFIG.localToken ~= "" then
		return "Bearer " .. CONFIG.localToken
	end
	warn("[AiBridge] No OpenACP token — set the `" .. CONFIG.secretKey .. "` Secret (see AiBridge.luau setup).")
	return nil
end

-- Returns the unwrapped `data` payload, or nil on any failure.
local function request(method: string, path: string, body: { [string]: any }?): { [string]: any }?
	local auth = authHeader()
	if not auth then
		return nil
	end
	local ok, res = pcall(function()
		return HttpService:RequestAsync({
			Url = CONFIG.baseUrl .. path,
			Method = method,
			Headers = {
				["Content-Type"] = "application/json",
				["Authorization"] = auth,
			},
			Body = body and HttpService:JSONEncode(body) or nil,
		})
	end)
	if not ok then
		warn("[AiBridge] request failed (HTTP enabled? token set?): " .. tostring(res))
		return nil
	end
	local response = res :: any
	if not response.Success then
		warn(("[AiBridge] %s %s -> HTTP %d"):format(method, path, response.StatusCode))
		return nil
	end
	local decoded
	pcall(function()
		decoded = HttpService:JSONDecode(response.Body)
	end)
	if type(decoded) ~= "table" or decoded.success == false then
		return nil
	end
	return decoded.data or decoded
end

-- Wrap the player's words so the agent runs the WHOLE loop unattended. Without this
-- the agent follows CLAUDE.md and pauses to ask "publish? (yes/no)" — which the game
-- can't answer, so it stalls (and our poll misreads the pause as "done"). Telling it
-- to publish automatically keeps it working straight through to a live build.
local function wrap(prompt: string): string
	return "[Automated build request from a player inside the live game. Make the change, "
		.. "validate with ./scripts/check.sh, then publish it live with ./scripts/publish.sh. "
		.. "Do NOT ask for confirmation — apply and publish automatically, then briefly say what "
		.. "you did.]\n\nPlayer's request: "
		.. prompt
end

-- Create a session and submit the build request. Returns the session id (to poll).
function AiBridge.send(prompt: string): string?
	local created = request("POST", CONFIG.apiBase, { agent = CONFIG.agent, workspace = CONFIG.workspace })
	local sessionId = created and created.sessionId
	if not sessionId then
		warn("[AiBridge] could not create session")
		return nil
	end
	request("POST", CONFIG.apiBase .. "/" .. sessionId .. "/prompt", { prompt = wrap(prompt) })
	return sessionId
end

-- Poll a session. Returns its status fields (caller checks .promptRunning/.status).
-- The single-session response nests the fields under `data.session`.
function AiBridge.status(sessionId: string): { [string]: any }?
	local data = request("GET", CONFIG.apiBase .. "/" .. sessionId, nil)
	return data and (data.session or data)
end

-- Poll the progress relay for new transcript lines after `since`.
-- Returns the new cursor and the friendly lines to show. Hits the relay (not OpenACP).
function AiBridge.progress(sessionId: string, since: number): (number, { string })
	local auth = authHeader()
	if not auth then
		return since, {}
	end
	local ok, res = pcall(function()
		return HttpService:RequestAsync({
			Url = CONFIG.progressBaseUrl .. "/progress?session=" .. sessionId .. "&since=" .. since,
			Method = "GET",
			Headers = { ["Authorization"] = auth },
		})
	end)
	if not ok or not (res :: any).Success then
		return since, {}
	end
	local decoded
	pcall(function()
		decoded = HttpService:JSONDecode((res :: any).Body)
	end)
	if type(decoded) ~= "table" then
		return since, {}
	end
	return tonumber(decoded.cursor) or since, decoded.lines or {}
end

return AiBridge
