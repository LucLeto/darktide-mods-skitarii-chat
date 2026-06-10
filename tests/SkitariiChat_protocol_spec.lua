local protocol = dofile("SkitariiChat/scripts/mods/SkitariiChat/SkitariiChat_protocol.lua")

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

local random_values = { 0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC }
local random_index = 0

local function deterministic_random_byte()
	random_index = random_index + 1

	return random_values[random_index] or 0xDE
end

local packets = assert(protocol.encode_message("Praise the Omnissiah", 3, deterministic_random_byte))
local packet = assert(protocol.decode_visible(packets[1]))

assert_equal(#packets, 1, "single packet count")
assert_equal(packet.message_id, 0x1234, "message id")
assert_equal(packet.part, 1, "part")
assert_equal(packet.total, 1, "total")
assert_equal(packet.payload, "Praise the Omnissiah", "payload")
assert_true(#packets[1] <= protocol.MAX_VISIBLE_PACKET_LENGTH, "visible packet exceeds safe length")
assert_true(not string.find(string.sub(packets[1], #protocol.MECHANICUS_GLYPH + 1), "[+/=]"), "packet is not base64url")

random_index = 0

local utf8_message = string.rep("a", 119) .. "\240\159\164\150" .. string.rep("\208\182", 70)
local utf8_packets = assert(protocol.encode_message(utf8_message, 3, deterministic_random_byte))
local decoded_chunks = {}

assert_equal(#utf8_packets, 3, "UTF-8 packet count")

for i = #utf8_packets, 1, -1 do
	local decoded = assert(protocol.decode_visible(utf8_packets[i]))

	decoded_chunks[decoded.part] = decoded.payload
end

assert_equal(table.concat(decoded_chunks), utf8_message, "UTF-8 reassembly")

local invalid_packet = string.sub(packets[1], 1, #protocol.MECHANICUS_GLYPH + 4)
	.. (string.sub(packets[1], #protocol.MECHANICUS_GLYPH + 5, #protocol.MECHANICUS_GLYPH + 5) == "A" and "B" or "A")
	.. string.sub(packets[1], #protocol.MECHANICUS_GLYPH + 6)

assert_true(protocol.decode_visible(invalid_packet) == nil, "mutated packet was accepted")
assert_true(protocol.decode_visible(protocol.MECHANICUS_GLYPH .. "not-a-packet") == nil, "invalid glyph message was accepted")

local too_long, too_long_error = protocol.encode_message(
	string.rep("x", protocol.PAYLOAD_BYTES_PER_PACKET * 3 + 1),
	3,
	deterministic_random_byte
)

assert_true(too_long == nil, "over-limit message was encoded")
assert_equal(too_long_error, "too_long", "over-limit error")

print("SkitariiChat protocol tests passed")
