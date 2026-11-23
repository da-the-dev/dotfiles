require("config.options") -- plain nvim settings; sets <leader>, so it must come before lazy
require("config.lazy") -- lazy.nvim bootstrap; loads every spec in lua/plugins/
require("config.keymaps")
