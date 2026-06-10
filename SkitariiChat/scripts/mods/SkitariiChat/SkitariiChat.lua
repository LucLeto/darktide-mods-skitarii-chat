local mod = get_mod("SkitariiChat")
local protocol = mod:io_dofile("SkitariiChat/scripts/mods/SkitariiChat/SkitariiChat_protocol")

local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local string_format = string.format
local table_concat = table.concat
local tostring = tostring

local CHUNK_TIMEOUT_SECONDS = 10
local CLEANUP_INTERVAL_SECONDS = 1

local command_enabled
local show_decoded_marker
local max_chunks
local debug_logging

local pending_messages = {}
local pending_count = 0
local next_cleanup_at = 0
local selected_channel_handle
local queued_command_message

local function refresh_settings()
	command_enabled = mod:get("enable_skitarii_chat")
	show_decoded_marker = mod:get("show_decoded_marker")
	max_chunks = math_min(protocol.MAX_PROTOCOL_CHUNKS, math_max(1, math_floor(tonumber(mod:get("max_chunks")) or 3)))
	debug_logging = mod:get("debug_logging")
end

local function debug_log(message, ...)
	if debug_logging then
		mod:info("[SKC1] " .. string_format(message, ...))
	end
end

local function current_time()
	local time_manager = Managers.time

	if time_manager then
		local t = time_manager:time("main")

		if t then
			return t
		end
	end

	return 0
end

local function clear_pending_messages()
	pending_messages = {}
	pending_count = 0
	next_cleanup_at = 0
end

local function cleanup_expired(now)
	if pending_count == 0 then
		next_cleanup_at = now + CLEANUP_INTERVAL_SECONDS

		return
	end

	for key, state in pairs(pending_messages) do
		if now - state.created_at >= CHUNK_TIMEOUT_SECONDS then
			pending_messages[key] = nil
			pending_count = pending_count - 1

			debug_log("expired message %d (%d/%d chunks)", state.message_id, state.received, state.total)
		end
	end

	next_cleanup_at = now + CLEANUP_INTERVAL_SECONDS
end

local function new_pending_message(sender_key, channel_key, packet, now)
	return {
		sender = sender_key,
		channel = channel_key,
		message_id = packet.message_id,
		total = packet.total,
		created_at = now,
		received = 0,
		chunks = {},
	}
end

local function collect_packet(sender, channel, packet)
	local sender_key = tostring(sender or "")
	local channel_key = tostring(channel.tag or channel.channel_name or channel)
	local key = sender_key .. "\0" .. channel_key .. "\0" .. packet.message_id
	local now = current_time()

	if now >= next_cleanup_at then
		cleanup_expired(now)
	end

	local state = pending_messages[key]

	if state and state.total ~= packet.total then
		pending_messages[key] = nil
		pending_count = pending_count - 1
		state = nil

		debug_log("reset conflicting message %d", packet.message_id)
	end

	if not state then
		state = new_pending_message(sender_key, channel_key, packet, now)
		pending_messages[key] = state
		pending_count = pending_count + 1
	end

	local existing_payload = state.chunks[packet.part]

	if existing_payload and existing_payload ~= packet.payload then
		state = new_pending_message(sender_key, channel_key, packet, now)
		pending_messages[key] = state
		existing_payload = nil

		debug_log("reset conflicting chunk %d for message %d", packet.part, packet.message_id)
	end

	if not existing_payload then
		state.chunks[packet.part] = packet.payload
		state.received = state.received + 1

		debug_log("collected message %d chunk %d/%d", packet.message_id, packet.part, packet.total)
	end

	if state.received ~= state.total then
		return nil
	end

	pending_messages[key] = nil
	pending_count = pending_count - 1

	return table_concat(state.chunks, "", 1, state.total)
end

local function send_encoded_message(channel_handle, message, send_packet)
	local packets, error_code = protocol.encode_message(message, max_chunks)

	if not packets then
		if error_code == "too_long" then
			mod:echo(mod:localize("message_too_long"))
		else
			mod:echo(mod:localize("command_usage"))
		end

		return false
	end

	if send_packet then
		for i = 1, #packets do
			send_packet(channel_handle, packets[i])
		end
	else
		local chat_manager = Managers.chat

		for i = 1, #packets do
			chat_manager:send_channel_message(channel_handle, packets[i])
		end
	end

	debug_log("sent %d chunk(s), %d payload bytes", #packets, #message)

	return true
end

refresh_settings()

mod:command("skc", mod:localize("command_description"), function(...)
	if not command_enabled then
		return
	end

	local message = queued_command_message
	queued_command_message = nil

	if message == nil then
		message = table_concat({ ... }, " ")
	end

	send_encoded_message(selected_channel_handle, message)
end)

if not command_enabled then
	mod:command_disable("skc")
end

mod:hook("ConstantElementChat", "_handle_active_chat_input", function(func, self, input_service, ui_renderer, ...)
	selected_channel_handle = self._selected_channel_handle

	if command_enabled and input_service:get("send_chat_message") then
		local input_widget = self._input_field_widget
		local input_text = input_widget and input_widget.content.input_text

		if type(input_text) == "string" then
			local command_prefix = string.lower(string.sub(input_text, 1, 5))

			if command_prefix == "/skc " then
				queued_command_message = self:_scrub(string.sub(input_text, 6))
			elseif string.lower(input_text) == "/skc" then
				queued_command_message = ""
			end
		end
	end

	return func(self, input_service, ui_renderer, ...)
end)

mod:hook("ChatManager", "send_channel_message", function(func, self, channel_handle, message_body)
	if command_enabled and type(message_body) == "string" and string.lower(string.sub(message_body, 1, 5)) == "/skc " then
		local message = string.sub(message_body, 6)

		send_encoded_message(channel_handle, message, function(handle, packet)
			func(self, handle, packet)
		end)

		return
	end

	return func(self, channel_handle, message_body)
end)

mod:hook("ConstantElementChat", "_add_message", function(func, self, message, sender, channel)
	if not command_enabled or type(message) ~= "string" or string.sub(message, 1, #protocol.MECHANICUS_GLYPH) ~= protocol.MECHANICUS_GLYPH then
		return func(self, message, sender, channel)
	end

	local packet = protocol.decode_visible(message)

	if not packet then
		return func(self, message, sender, channel)
	end

	local decoded_message = collect_packet(sender, channel, packet)

	if not decoded_message then
		return
	end

	decoded_message = self:_scrub(decoded_message)

	if show_decoded_marker then
		decoded_message = protocol.MECHANICUS_GLYPH .. " " .. decoded_message
	end

	return func(self, decoded_message, sender, channel)
end)

mod.update = function()
	if pending_count > 0 then
		local now = current_time()

		if now >= next_cleanup_at then
			cleanup_expired(now)
		end
	end
end

mod.on_setting_changed = function()
	local was_enabled = command_enabled

	refresh_settings()

	if command_enabled then
		mod:command_enable("skc")
	else
		mod:command_disable("skc")
	end

	if was_enabled and not command_enabled then
		clear_pending_messages()
		queued_command_message = nil
	end
end

mod.on_enabled = function()
	refresh_settings()

	if not command_enabled then
		mod:command_disable("skc")
	end
end

mod.on_disabled = function()
	clear_pending_messages()
	queued_command_message = nil
	selected_channel_handle = nil
end
