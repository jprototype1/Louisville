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
	agent = "claude",
	workspace = "/Users/gnijor/roblox/brookhaven",
	-- Roblox Secret key holding the access token (preferred — keeps it out of code).
	secretKey = "openacp_token",
	-- Studio/local-only fallback. KEEP BLANK in commits — anything here ships live.
	localToken = "",
}

local AiBridge = {}

-- Build the authed URL for a path. Uses a Roblox Secret when available (so the
-- token value never appears in readable code), else the local fallback.
local function authedUrl(path: string): (string | Secret)?
	local base = CONFIG.baseUrl .. path .. "?code="
	local ok, secret = pcall(function()
		return HttpService:GetSecret(CONFIG.secretKey)
	end)
	if ok and secret then
		-- Secret:AddPrefix keeps the token opaque; result is usable as a request URL.
		return secret:AddPrefix(base)
	end
	if CONFIG.localToken ~= "" then
		return base .. CONFIG.localToken
	end
	warn("[AiBridge] No OpenACP token — set the `" .. CONFIG.secretKey .. "` Secret (see AiBridge.luau setup).")
	return nil
end

local function request(method: string, path: string, body: { [string]: any }?): { [string]: any }?
	local url = authedUrl(path)
	if not url then
		return nil
	end
	local ok, res = pcall(function()
		return HttpService:RequestAsync({
			Url = url,
			Method = method,
			Headers = { ["Content-Type"] = "application/json" },
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
	return decoded
end

-- Create a session and submit the build request. Returns the session id (to poll).
function AiBridge.send(prompt: string): string?
	local created = request("POST", "/api/sessions", { agent = CONFIG.agent, workspace = CONFIG.workspace })
	local sessionId = created and (created.id or created.sessionId)
	if not sessionId then
		warn("[AiBridge] could not create session")
		return nil
	end
	request("POST", "/api/sessions/" .. sessionId .. "/prompt", { prompt = prompt })
	return sessionId
end

-- Poll a session. Returns its raw status object (caller decides when it's "done").
function AiBridge.status(sessionId: string): { [string]: any }?
	return request("GET", "/api/sessions/" .. sessionId, nil)
end

return AiBridge
