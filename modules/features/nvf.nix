{ self, inputs, ... }: {
  flake.nixosModules.nvf = { pkgs, lib, ... }: {
    home-manager.users.sim = {
      imports = [ inputs.nvf.homeManagerModules.default ];

      programs.nvf = {
        enable = true;
        settings = {
          vim = {
            viAlias = false;
            vimAlias = true;

            # leader key = space
            globals.mapleader = " ";

            theme = {
              enable = true;
              name = "tokyonight";
              style = "night";
              transparent = true; # see-through background
            };

            # brighter, more readable line numbers (fg only — keeps gutter transparent)
            options = {
              cursorline = true;
              cursorlineopt = "number";
            };

            luaConfigRC.linenr_colors = ''
              vim.api.nvim_set_hl(0, "LineNr", { fg = "#73daca" })
              vim.api.nvim_set_hl(0, "LineNrAbove", { fg = "#73daca" })
              vim.api.nvim_set_hl(0, "LineNrBelow", { fg = "#73daca" })
              vim.api.nvim_set_hl(0, "CursorLineNr", { fg = "#27a1b9", bold = true })
            '';

            lsp.enable = true;
            treesitter.enable = true;

            languages = {
              enableTreesitter = true;
              nix.enable = true;
              clang.enable = true; # C/C++ (clangd + clang-format + clangtidy)
              cmake.enable = true; # CMake LSP (neocmakelsp)
            };

            # tools that plugins/formatters/linters below invoke — must be on nvim's PATH
            extraPackages = [
              pkgs.luau-lsp
              pkgs.stylua
              pkgs.selene
              pkgs.cmake
              pkgs.ninja # build program
              pkgs.gcc # C++ compiler (g++)
            ];

            # Luau LSP via luau-lsp.nvim — it owns the LSP setup itself.
            extraPlugins.luau-lsp-nvim = {
              package = pkgs.vimPlugins.luau-lsp-nvim;
              setup = ''
                require("luau-lsp").setup({
                  platform = { type = "roblox" },
                  types = { roblox_security_level = "PluginSecurity" },
                  server = {
                    cmd = { "${pkgs.luau-lsp}/bin/luau-lsp", "lsp" },
                  },
                })
              '';
            };

            # cmake-tools.nvim — build/configure/run/debug from inside nvim
            extraPlugins.cmake-tools = {
              package = pkgs.vimPlugins.cmake-tools-nvim;
              setup = ''
                require("cmake-tools").setup({
                  cmake_command = "${pkgs.cmake}/bin/cmake",
                  ctest_command = "${pkgs.cmake}/bin/ctest",
                  cmake_build_directory = "build",
                  cmake_generate_options = { "-G", "Ninja", "-DCMAKE_EXPORT_COMPILE_COMMANDS=1" },
                })
              '';
            };

            # harpoon2 — quick file marking and jumping
            extraPlugins.harpoon = {
              package = pkgs.vimPlugins.harpoon2;
              setup = ''
                local harpoon = require("harpoon")
                harpoon:setup({
                  settings = { save_on_toggle = true },
                })

                -- open files in splits/tabs from the harpoon menu
                harpoon:extend({
                  UI_CREATE = function(cx)
                    vim.keymap.set("n", "<C-v>", function()
                      harpoon.ui:select_menu_item({ vsplit = true })
                    end, { buffer = cx.bufnr })
                    vim.keymap.set("n", "<C-x>", function()
                      harpoon.ui:select_menu_item({ split = true })
                    end, { buffer = cx.bufnr })
                    vim.keymap.set("n", "<C-t>", function()
                      harpoon.ui:select_menu_item({ tabedit = true })
                    end, { buffer = cx.bufnr })
                  end,
                })

                -- add current file / toggle the built-in menu
                vim.keymap.set("n", "<leader>hm", function() harpoon:list():add() end,
                  { desc = "Harpoon add file" })
                vim.keymap.set("n", "<leader>hh", function()
                  harpoon.ui:toggle_quick_menu(harpoon:list())
                end, { desc = "Harpoon menu" })

                -- open harpoon list inside telescope (fuzzy-findable)
                local conf = require("telescope.config").values
                local function toggle_telescope(harpoon_files)
                  local file_paths = {}
                  for _, item in ipairs(harpoon_files.items) do
                    table.insert(file_paths, item.value)
                  end

                  require("telescope.pickers").new({}, {
                    prompt_title = "Harpoon",
                    finder = require("telescope.finders").new_table({
                      results = file_paths,
                    }),
                    previewer = conf.file_previewer({}),
                    sorter = conf.generic_sorter({}),
                  }):find()
                end

                vim.keymap.set("n", "<leader>fh", function()
                  toggle_telescope(harpoon:list())
                end, { desc = "Harpoon (Telescope)" })
              '';
            };

            # keybindings
            keymaps = [
              {
                key = "<leader>cb";
                mode = "n";
                silent = true;
                action = "<cmd>CMakeBuild<cr>";
                desc = "CMake Build";
              }
              {
                key = "<leader>cr";
                mode = "n";
                silent = true;
                action = "<cmd>CMakeRun<cr>";
                desc = "CMake Run";
              }

              # telescope
              {
                key = "<leader>ff";
                mode = "n";
                silent = true;
                action = "<cmd>Telescope find_files<cr>";
                desc = "Find files";
              }
              {
                key = "<leader>fg";
                mode = "n";
                silent = true;
                action = "<cmd>Telescope live_grep<cr>";
                desc = "Live grep";
              }
              {
                key = "<leader>fk";
                mode = "n";
                silent = true;
                action = "<cmd>Telescope keymaps<cr>";
                desc = "Keymaps";
              }
              {
                key = "<leader>fc";
                mode = "n";
                silent = true;
                action = "<cmd>Telescope commands<cr>";
                desc = "Commands";
              }
              {
                key = "<leader>fd";
                mode = "n";
                silent = true;
                action = "<cmd>Telescope lsp_definitions<cr>";
                desc = "Definitions";
              }
              {
                key = "<leader>fr";
                mode = "n";
                silent = true;
                action = "<cmd>Telescope lsp_references<cr>";
                desc = "References";
              }
            ];

            # stylua formatting for luau (format-on-save via lsp.formatOnSave below)
            formatter.conform-nvim = {
              enable = true;
              setupOpts.formatters_by_ft.luau = [ "stylua" ];
            };

            # selene linting for luau — diagnostics show inline alongside luau-lsp
            diagnostics.nvim-lint = {
              enable = true;
              linters_by_ft.luau = [ "selene" ];
            };

            # format on save
            lsp.formatOnSave = true;

            # utility bits
            telescope.enable = true;
            autocomplete.nvim-cmp.enable = true;
            statusline.lualine.enable = true;
          };
        };
      };
    };
  };
}
