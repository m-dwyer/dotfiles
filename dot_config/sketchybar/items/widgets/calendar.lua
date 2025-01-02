local settings = require("config.settings-old")
local colors = require("config.colors")
local cal = sbar.add("item", {
	icon = {
		color = colors.white,
		font = {
			style = settings.fonts.styles.regular,
			size = 12.0,
		},
		-- y_offset = -1,
		padding_right = -2,
	},
	background = {
			color = colors.bg2,
			border_color = colors.bg2,
			-- border_width = 2,
	},
	label = {
		color = colors.white,
		width = 96,
		align = "left",
		font = {
			style = settings.fonts.styles.regular,
			size = 14.0,
		},
	},
	position = "right",
	update_freq = 1,
	y_offset = 0,
	padding_left = settings.dimens.padding.item,
})

cal:subscribe({ "forced", "routine", "system_woke" }, function(env)
	local weekdayNames = {
		"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"
	}
	local monthNames = {
		"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
	}

	cal:set({
		icon = weekdayNames[tonumber(os.date("%w")) + 1] .. " " ..
			os.date("%d") .. " " .. monthNames[tonumber(os.date("%m"))],
		label = "｜" .. os.date("%H:%M:%S")
	})
end)

-- sbar.add("bracket", "calendar.bracket", { cal.name }, {
-- 	background = {
-- 		color = colors.bg2,
-- 		border_color = colors.bg2,
-- 		border_width = 2,
-- 		padding_left = 0
-- 	},
-- })

-- english date
-- cal:subscribe({ "forced", "routine", "system_woke" }, function(env)
--   cal:set({ icon = os.date("%a. %d %b."), label = os.date("%H:%M") })
-- end)