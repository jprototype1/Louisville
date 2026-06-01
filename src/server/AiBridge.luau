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
--   2. Store the OpenACP access token as a Roblox Secret so it is NEVER in code:
--        Creator Dashboard → your experience → Secrets → add key `openacp_token`
--        with value = a scoped token minted by:  openacp remote --name in-game
--      (Falls back to LOCAL_TOKEN below only for Studio testing — leave it blank
--       in commits; the token would otherwise ship inside the published game.)
--   3. Confirm CONFIG.baseUrl matches your tunnel (openacp remote prints it).

local HttpService = game:GetService("HttpService")

local CONFIG = {
	-- Public OpenACP tunnel base (NOT secret — just the hostname). From `openacp remote`.
	baseUrl = "https://tunnel-ed6ee4e1.openacp.ai",
	-- Which agent + workspace OpenACP should spin the session up in.
	apiBase = "/api/v1/sessions",
	agent = "claude",
	workspace = "/Users/gnijor/roblox/brookhaven",
	-- Roblox Secret key holding the Bearer token (preferred — keeps it out of code).
	secretKey = "openacp_token",
	-- Studio/local-only fallback. KEEP BLANK in commits — anything here ships live.
	localToken = "",
}

-- API contract verified live against the OpenACP daemon (2026-06-01):
--   * routes live under /api/v1/sessions
--   * auth is an `Authorization: Bearer <token>` header (the ?code= in `openacp
--     remote` is a one-time browser code, NOT a durable token — see OPEN ITEM below)
--   * responses are wrapped: { success = bool, data = {...} }
--
-- ⚠️ OPEN ITEM: `openacp remote` tokens currently expire in ~30 min, so they aren't
-- suitable to embed. A durable Bearer token (or a code→JWT exchange step) still needs
-- to be sorted before this works unattended.

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

-- Create a session and submit the build request. Returns the session id (to poll).
function AiBridge.send(prompt: string): string?
	local created = request("POST", CONFIG.apiBase, { agent = CONFIG.agent, workspace = CONFIG.workspace })
	local sessionId = created and created.sessionId
	if not sessionId then
		warn("[AiBridge] could not create session")
		return nil
	end
	request("POST", CONFIG.apiBase .. "/" .. sessionId .. "/prompt", { prompt = prompt })
	return sessionId
end

-- Poll a session. Returns its status fields (caller checks .promptRunning/.status).
-- The single-session response nests the fields under `data.session`.
function AiBridge.status(sessionId: string): { [string]: any }?
	local data = request("GET", CONFIG.apiBase .. "/" .. sessionId, nil)
	return data and (data.session or data)
end

return AiBridge
