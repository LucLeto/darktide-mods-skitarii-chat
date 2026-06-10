local mod = get_mod("SkitariiChat")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "enable_skitarii_chat",
				type = "checkbox",
				default_value = true,
				tooltip = "enable_skitarii_chat_tooltip",
			},
			{
				setting_id = "show_decoded_marker",
				type = "checkbox",
				default_value = true,
				tooltip = "show_decoded_marker_tooltip",
			},
			{
				setting_id = "max_chunks",
				type = "numeric",
				default_value = 3,
				range = { 1, 10 },
				tooltip = "max_chunks_tooltip",
			},
			{
				setting_id = "debug_logging",
				type = "checkbox",
				default_value = false,
				tooltip = "debug_logging_tooltip",
			},
		},
	},
}
