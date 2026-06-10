local hooks = {}
local commands = {}
local settings = {
	enable_skitarii_chat = true,
	show_decoded_marker = true,
	max_chunks = 3,
	debug_logging = false,
}
local echoes = {}
local sent_messages = {}
local now = 0

local mod = {}

function mod:get(setting_id)
	return settings[setting_id]
end

function mod:localize(key)
	local values = {
		message_too_long = "Skitarii Chat message is too long.",
		command_usage = "Usage: /skc <message>",
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

settings.enable_skitarii_chat = false
mod.on_setting_changed()

assert_true(not skc_command.enabled, "disabled setting left DMF command enabled")

settings.enable_skitarii_chat = true
mod.on_setting_changed()

assert_true(skc_command.enabled, "enabled setting left DMF command disabled")

print("SkitariiChat integration tests passed")
