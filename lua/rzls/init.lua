local handlers = require("rzls.handlers")
local documentstore = require("rzls.documentstore")
local razor = require("rzls.razor")
local Log = require("rzls.log")

local M = {}

local sysname = vim.uv.os_uname().sysname:lower()
local iswin = not not (sysname:find("windows") or sysname:find("mingw"))

---@class rzls.Config
---@field on_attach function
---@field capabilities table
---@field path string?

--- return the path to the rzls executable
---@param config rzls.Config
---@return string
local function get_cmd_path(config)
    local data = vim.fs.normalize(vim.fn.stdpath("data") --[[@as string]])
    local mason_path = vim.fs.joinpath(data, "mason", "bin", "rzls")
    local mason_installation = iswin and string.format("%s.cmd", mason_path) or mason_path

    if vim.uv.fs_stat(mason_installation) ~= nil then
        return mason_installation
    end

    return config.path
end

---@type rzls.Config
local defaultConfg = {
    on_attach = function()
        return nil
    end,
    capabilities = vim.lsp.protocol.make_client_capabilities(),
}

---@param config rzls.Config
function M.setup(config)
    Log.rzlsnvim = "Setting rzls config"
    local rzlsconfig = vim.tbl_deep_extend("force", defaultConfg, config)
    rzlsconfig.path = get_cmd_path(rzlsconfig)
    vim.filetype.add({
        extension = {
            razor = "razor",
        },
    })

    local au = vim.api.nvim_create_augroup("rzls", { clear = true })

    vim.api.nvim_create_autocmd("FileType", {
        pattern = { "razor" },
        callback = function(ev)
            local root_dir = vim.fn.expand("%:h:p")
            local lsp_client_id = vim.lsp.start({
                name = "rzls",
                cmd = {
                    rzlsconfig.path,
                    "--logLevel",
                    "0",
                    "--DelegateToCSharpOnDiagnosticPublish",
                    "true",
                    "--UpdateBuffersForClosedDocuments",
                    "true",
                },
                on_init = function(client, _initialize_result)
                    root_dir = client.root_dir
                    documentstore.load_existing_files(client.root_dir)
                    ---@module "roslyn"
                    local roslyn_pipes = require("roslyn.server").get_pipes()
                    vim.notify("roslyn client root: " .. client.root_dir)
                    if roslyn_pipes[root_dir] then
                        documentstore.initialize(client)
                    else
                        vim.api.nvim_create_autocmd("User", {
                            pattern = "RoslynInitialized",
                            callback = function()
                                documentstore.initialize(client)
                            end,
                            group = au,
                        })
                    end
                end,
                root_dir = root_dir,
                on_attach = function(client, bufnr)
                    vim.notify("starting rzls: " .. rzlsconfig.path)
                    razor.apply_highlights()
                    documentstore.register_vbufs_by_path(vim.uri_to_fname(vim.uri_from_bufnr(bufnr)), true)
                    rzlsconfig.on_attach(client, bufnr)
                end,
                capabilities = rzlsconfig.capabilities,
                settings = {
                    html = vim.empty_dict(),
                    razor = vim.empty_dict(),
                },
                handlers = handlers,
            })

            if lsp_client_id == nil then
                vim.notify("Could not start Razor LSP", vim.log.levels.ERROR, { title = "rzls.nvim" })
                return
            end

            vim.lsp.buf_attach_client(ev.buf, lsp_client_id)

            local aftershave_client_id = vim.lsp.start({
                name = "aftershave",
                root_dir = root_dir,
                cmd = require("rzls.server.lsp").server,
            })

            if aftershave_client_id == nil then
                vim.notify("Could not start aftershave LSP", vim.log.levels.ERROR, { title = "rzls.nvim" })
                return
            end

            vim.lsp.buf_attach_client(ev.buf, aftershave_client_id)
        end,
        group = au,
    })

    vim.treesitter.language.register("html", { "razor" })

    vim.api.nvim_create_autocmd("ColorScheme", {
        group = au,
        callback = razor.apply_highlights,
    })
end

return M
