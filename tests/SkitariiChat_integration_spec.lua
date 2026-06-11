local hooks = {}
local commands = {}
local settings = {
	encode_mode = "command",
	decode_incoming_messages = true,
	show_decoded_marker = true,
	max_chunks = 3,
	debug_logging = false,
}
local echoes = {}
local warnings = {}
local sent_messages = {}
local command_gui_destroy_count = 0
local remote_requests = {}
local now = 0

local mod = {}

function mod:get(setting_id)
	return settings[setting_id]
end

function mod:localize(key)
	local values = {
		message_too_long = "Skitarii Chat message is too long.",
		command_usage = "Usage: /skc <message>",
		encoding_disabled = "Skitarii Chat outgoing encoding is off.",
		chat_channel_unavailable = "Skitarii Chat could not find an active chat channel.",
		mod_enabled = "Skitarii Chat enabled.",
		mod_disabled = "Skitarii Chat disabled.",
		remote_disabled = "Skitarii Chat has been remotely disabled by its maintainer.",
		remote_enabled = "Skitarii Chat remote access restored.",
		command_description = "Send an encoded Skitarii Chat message. Usage: /skc <message>",
	}

	return values[key] or key
end

function mod:echo(message)
	echoes[#echoes + 1] = message
end

function mod:info()
	return
end

function mod:warning(message)
	warnings[#warnings + 1] = message
end

function mod.destroy_command_gui()
	command_gui_destroy_count = command_gui_destroy_count + 1
end

function mod:hook(class_name, method_name, hook)
	hooks[class_name .. "." .. method_name] = hook
end

function mod:command(command_name, description, callback)
	commands[command_name] = {
		description = description,
		callback = callback,
		enabled = true,
	}
end

function mod:command_enable(command_name)
	commands[command_name].enabled = true
end

function mod:command_disable(command_name)
	commands[command_name].enabled = false
end

function mod:io_dofile(path)
	return dofile(path .. ".lua")
end

function get_mod()
	return mod
end

Managers = {
	time = {
		time = function()
			return now
		end,
	},
	chat = {
		send_channel_message = function(_, channel_handle, message)
			sent_messages[#sent_messages + 1] = {
				channel_handle = channel_handle,
				message = message,
			}
		end,
	},
	backend = {
		url_request = function(_, url, options)
			local promise = {}

			function promise:next(on_fulfilled, on_rejected)
				self.on_fulfilled = on_fulfilled
				self.on_rejected = on_rejected

				return self
			end

			remote_requests[#remote_requests + 1] = {
				url = url,
				options = options,
				promise = promise,
			}

			return promise
		end,
	},
}

dofile("SkitariiChat/scripts/mods/SkitariiChat/SkitariiChat.lua")

local protocol = dofile("SkitariiChat/scripts/mods/SkitariiChat/SkitariiChat_protocol.lua")
local active_input_hook = hooks["ConstantElementChat._handle_active_chat_input"]
local send_hook = hooks["ChatManager.send_channel_message"]
local add_hook = hooks["ConstantElementChat._add_message"]
local skc_command = commands.skc

local function assert_equal(actual, expected, label)
	if actual ~= expected then
		error(string.format("%s: expected %q, got %q", label, expected, actual))
	end
end

local function assert_true(value, label)
	if not value then
		error(label)
	end
end

local chat_element = {
	_selected_channel_handle = "mission-channel",
	_input_field_widget = {
		content = {
			input_text = "",
		},
	},
	_scrub = function(_, text)
		return string.gsub(text, "{#.-}", "")
	end,
}
local channel = {
	tag = "mission",
}

local function submit_chat_input(input_text)
	chat_element._input_field_widget.content.input_text = input_text

	active_input_hook(function()
		return
	end, chat_element, {
		get = function(_, action)
			return action == "send_chat_message"
		end,
	}, nil)
end

assert_true(skc_command ~= nil, "DMF command was not registered")
assert_true(skc_command.enabled, "DMF command was not enabled")

submit_chat_input("/skc  preserve  spacing ")
skc_command.callback("preserve", "spacing")

assert_equal(#sent_messages, 1, "exact-spacing packet count")
assert_equal(sent_messages[1].channel_handle, "mission-channel", "exact-spacing channel")
assert_equal(
	assert(protocol.decode_visible(sent_messages[1].message)).payload,
	" preserve  spacing ",
	"exact slash payload"
)

sent_messages = {}

submit_chat_input("/skc Praise the Omnissiah")
skc_command.callback("Praise", "the", "Omnissiah")

assert_equal(#sent_messages, 1, "single outgoing packet count")
assert_equal(sent_messages[1].channel_handle, "mission-channel", "outgoing channel")
assert_equal(assert(protocol.decode_visible(sent_messages[1].message)).payload, "Praise the Omnissiah", "outgoing payload")

local displayed = {}

local function display_message(_, message, sender, message_channel)
	displayed[#displayed + 1] = {
		message = message,
		sender = sender,
		channel = message_channel,
	}
end

add_hook(display_message, chat_element, sent_messages[1].message, "You", channel)

assert_equal(#displayed, 1, "decoded sender display count")
assert_equal(displayed[1].message, protocol.MECHANICUS_GLYPH .. " Praise the Omnissiah", "decoded sender display")

add_hook(display_message, chat_element, protocol.MECHANICUS_GLYPH .. "not-a-packet", "Other", channel)

assert_equal(#displayed, 2, "invalid packet display count")
assert_equal(displayed[2].message, protocol.MECHANICUS_GLYPH .. "not-a-packet", "invalid packet passthrough")

sent_messages = {}

local long_message = string.rep("a", 119) .. "\240\159\164\150" .. string.rep("\208\182", 70)

submit_chat_input("/skc " .. long_message)
skc_command.callback(long_message)

assert_equal(#sent_messages, 3, "multi-chunk outgoing count")

displayed = {}

add_hook(display_message, chat_element, sent_messages[2].message, "Other", channel)
add_hook(display_message, chat_element, sent_messages[3].message, "Other", channel)

assert_equal(#displayed, 0, "partial chunks were displayed")

add_hook(display_message, chat_element, sent_messages[1].message, "Other", channel)

assert_equal(#displayed, 1, "reassembled display count")
assert_equal(displayed[1].message, protocol.MECHANICUS_GLYPH .. " " .. long_message, "reassembled UTF-8 display")

local fallback_sent = {}

send_hook(function(_, channel_handle, message)
	fallback_sent[#fallback_sent + 1] = {
		channel_handle = channel_handle,
		message = message,
	}
end, Managers.chat, "fallback-channel", "plain command-mode message")

assert_equal(#fallback_sent, 1, "command-mode passthrough count")
assert_equal(fallback_sent[1].message, "plain command-mode message", "command-mode passthrough message")

fallback_sent = {}

send_hook(function(_, channel_handle, message)
	fallback_sent[#fallback_sent + 1] = {
		channel_handle = channel_handle,
		message = message,
	}
end, Managers.chat, "fallback-channel", "/skc fallback path")

assert_equal(#fallback_sent, 1, "fallback packet count")
assert_equal(fallback_sent[1].channel_handle, "fallback-channel", "fallback channel")
assert_equal(assert(protocol.decode_visible(fallback_sent[1].message)).payload, "fallback path", "fallback payload")

sent_messages = {}

local over_limit_message = string.rep("x", protocol.PAYLOAD_BYTES_PER_PACKET * 3 + 1)

submit_chat_input("/skc " .. over_limit_message)
skc_command.callback(over_limit_message)

assert_equal(#sent_messages, 0, "over-limit message was sent")
assert_equal(echoes[#echoes], "Skitarii Chat message is too long.", "over-limit warning")

sent_messages = {}

submit_chat_input("/skc " .. long_message)
skc_command.callback(long_message)

displayed = {}

add_hook(display_message, chat_element, sent_messages[1].message, "Other", channel)

now = 11
mod.update()

add_hook(display_message, chat_element, sent_messages[2].message, "Other", channel)
add_hook(display_message, chat_element, sent_messages[3].message, "Other", channel)

assert_equal(#displayed, 0, "expired partial message was reassembled")

add_hook(display_message, chat_element, sent_messages[1].message, "Other", channel)

assert_equal(#displayed, 1, "new chunk set did not reassemble")

settings.encode_mode = "off"
mod.on_setting_changed()

sent_messages = {}

submit_chat_input("/skc disabled message")
skc_command.callback("disabled", "message")

assert_equal(#sent_messages, 0, "off mode sent a command message")
assert_equal(echoes[#echoes], "Skitarii Chat outgoing encoding is off.", "off-mode warning")

local off_mode_sent = {}

send_hook(function(_, channel_handle, message)
	off_mode_sent[#off_mode_sent + 1] = {
		channel_handle = channel_handle,
		message = message,
	}
end, Managers.chat, "off-channel", "plain off-mode message")

assert_equal(#off_mode_sent, 1, "off-mode passthrough count")
assert_equal(off_mode_sent[1].message, "plain off-mode message", "off-mode passthrough message")

local incoming_packet = assert(protocol.encode_message("Incoming still decodes", 3))[1]

displayed = {}

add_hook(display_message, chat_element, incoming_packet, "Other", channel)

assert_equal(#displayed, 1, "off mode did not decode incoming packet")
assert_equal(
	displayed[1].message,
	protocol.MECHANICUS_GLYPH .. " Incoming still decodes",
	"off-mode incoming decoded message"
)

settings.decode_incoming_messages = false
mod.on_setting_changed()

displayed = {}

add_hook(display_message, chat_element, incoming_packet, "Other", channel)

assert_equal(#displayed, 1, "disabled incoming decoding display count")
assert_equal(displayed[1].message, incoming_packet, "disabled incoming decoding changed packet")

settings.decode_incoming_messages = true
mod.on_setting_changed()

settings.encode_mode = "always"
mod.on_setting_changed()

local always_mode_sent = {}

local function capture_always_send(_, channel_handle, message)
	always_mode_sent[#always_mode_sent + 1] = {
		channel_handle = channel_handle,
		message = message,
	}
end

send_hook(capture_always_send, Managers.chat, "always-channel", "Every message is sacred")

assert_equal(#always_mode_sent, 1, "always-mode packet count")
assert_equal(always_mode_sent[1].channel_handle, "always-channel", "always-mode channel")
assert_equal(
	assert(protocol.decode_visible(always_mode_sent[1].message)).payload,
	"Every message is sacred",
	"always-mode payload"
)

local encoded_packet = always_mode_sent[1].message

always_mode_sent = {}

send_hook(capture_always_send, Managers.chat, "always-channel", encoded_packet)

assert_equal(#always_mode_sent, 1, "encoded packet passthrough count")
assert_equal(always_mode_sent[1].message, encoded_packet, "encoded packet was encoded again")

always_mode_sent = {}

send_hook(capture_always_send, Managers.chat, "always-channel", "/help")

assert_equal(#always_mode_sent, 1, "slash-command passthrough count")
assert_equal(always_mode_sent[1].message, "/help", "slash command was encoded")

always_mode_sent = {}

send_hook(capture_always_send, Managers.chat, "always-channel", "/skc explicit command")

assert_equal(#always_mode_sent, 1, "always-mode explicit command packet count")
assert_equal(
	assert(protocol.decode_visible(always_mode_sent[1].message)).payload,
	"explicit command",
	"always-mode explicit command payload"
)

local echo_count_before_initial_lifecycle = #echoes

mod.on_enabled(true)

assert_true(skc_command.enabled, "initial enable left DMF command disabled")
assert_equal(#echoes, echo_count_before_initial_lifecycle, "initial enable produced an echo")

mod.on_disabled(false)

assert_true(not skc_command.enabled, "disabled mod left DMF command enabled")
assert_equal(echoes[#echoes], "Skitarii Chat disabled.", "disabled-mod echo")

local disabled_echo_count = #echoes

skc_command.callback("queued", "after", "disable")

assert_equal(#echoes, disabled_echo_count + 1, "nil-channel guard did not echo")
assert_equal(echoes[#echoes], "Skitarii Chat could not find an active chat channel.", "nil-channel warning")

mod.on_enabled(false)

assert_true(skc_command.enabled, "re-enabled mod left DMF command disabled")
assert_equal(echoes[#echoes], "Skitarii Chat enabled.", "enabled-mod echo")

submit_chat_input("/skc recovered")
skc_command.callback("recovered")

assert_equal(
	assert(protocol.decode_visible(sent_messages[#sent_messages].message)).payload,
	"recovered",
	"re-enabled command payload"
)

local stale_gui_error = "bad argument #1 to 'slug_text_extents' (Gui expected, got userdata)"
local stale_gui_succeeded = pcall(function()
	active_input_hook(function()
		error(stale_gui_error)
	end, chat_element, {
		get = function()
			return false
		end,
	}, nil)
end)

assert_true(stale_gui_succeeded, "stale DMF command GUI error escaped the chat hook")
assert_equal(command_gui_destroy_count, 1, "stale DMF command GUI was not reset")
assert_equal(warnings[#warnings], "[SKC1] Recovered from a stale DMF command autocomplete GUI.", "recovery warning")

local unrelated_error_succeeded, unrelated_error = pcall(function()
	active_input_hook(function()
		error("unrelated downstream failure")
	end, chat_element, {
		get = function()
			return false
		end,
	}, nil)
end)

assert_true(not unrelated_error_succeeded, "unrelated chat hook error was suppressed")
assert_true(string.find(unrelated_error, "unrelated downstream failure", 1, true) ~= nil, "wrong unrelated error")

local request_count_before_state_change = #remote_requests

mod.on_game_state_changed("enter", "StateGameScore")

assert_equal(#remote_requests, request_count_before_state_change, "non-gameplay state triggered remote check")

mod.on_game_state_changed("enter", "StateGameplay")

assert_equal(#remote_requests, request_count_before_state_change + 1, "gameplay state did not trigger remote check")

local first_remote_request = remote_requests[#remote_requests]

assert_true(
	string.find(first_remote_request.url, "SKCE?check=", 1, true) ~= nil,
	"remote check used the wrong URL"
)
assert_equal(first_remote_request.options.method, "GET", "remote check method")
assert_equal(first_remote_request.options.require_auth, false, "remote check authentication")
assert_equal(first_remote_request.options.response_timeout_seconds, 10, "remote check timeout")
assert_equal(first_remote_request.options.headers["Cache-Control"], "no-cache", "remote check cache control")

first_remote_request.promise.on_fulfilled({
	status = 200,
	body = "",
})

assert_true(skc_command.enabled, "successful remote check disabled the command")

mod.on_game_state_changed("enter", "StateGameplay")

local missing_remote_request = remote_requests[#remote_requests]

missing_remote_request.promise.on_rejected({
	status = 404,
})

assert_true(not skc_command.enabled, "missing remote marker left the command enabled")
assert_equal(echoes[#echoes], "Skitarii Chat has been remotely disabled by its maintainer.", "remote disable echo")

local remotely_disabled_sent = {}

send_hook(function(_, channel_handle, message)
	remotely_disabled_sent[#remotely_disabled_sent + 1] = {
		channel_handle = channel_handle,
		message = message,
	}
end, Managers.chat, "remote-disabled-channel", "Remote disabled passthrough")

assert_equal(#remotely_disabled_sent, 1, "remote disable swallowed normal chat")
assert_equal(remotely_disabled_sent[1].message, "Remote disabled passthrough", "remote disable changed normal chat")

remotely_disabled_sent = {}

send_hook(function(_, channel_handle, message)
	remotely_disabled_sent[#remotely_disabled_sent + 1] = {
		channel_handle = channel_handle,
		message = message,
	}
end, Managers.chat, "remote-disabled-channel", "/skc blocked")

assert_equal(#remotely_disabled_sent, 0, "remote disable sent an SKC1 command")
assert_equal(echoes[#echoes], "Skitarii Chat has been remotely disabled by its maintainer.", "blocked command echo")

displayed = {}

add_hook(display_message, chat_element, incoming_packet, "Other", channel)

assert_equal(#displayed, 1, "remote disable swallowed incoming packet")
assert_equal(displayed[1].message, incoming_packet, "remote disable decoded incoming packet")

local warning_count_before_network_failure = #warnings

mod.on_game_state_changed("enter", "StateGameplay")

local failed_remote_request = remote_requests[#remote_requests]

failed_remote_request.promise.on_rejected({
	code = 0,
})

assert_true(not skc_command.enabled, "network failure changed cached remote-disabled state")
assert_equal(#warnings, warning_count_before_network_failure + 1, "network failure was not logged")

mod.on_game_state_changed("enter", "StateGameplay")

local stale_remote_request = remote_requests[#remote_requests]

mod.on_game_state_changed("enter", "StateGameplay")

local restored_remote_request = remote_requests[#remote_requests]

stale_remote_request.promise.on_rejected({
	status = 404,
})
restored_remote_request.promise.on_fulfilled({
	status = 200,
	body = "",
})

assert_true(skc_command.enabled, "restored remote marker left the command disabled")
assert_equal(echoes[#echoes], "Skitarii Chat remote access restored.", "remote restore echo")

print("SkitariiChat integration tests passed")
