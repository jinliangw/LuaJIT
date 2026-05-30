local utils = require('pl.utils')
local config = require('pl.config')

local info = {}

local function strip(s)
    return s and s:match("^%s*(.-)%s*$") or ""
end

local function get_cpu_stats()
    local stat_str = utils.readfile('/proc/stat')
    if not stat_str then return nil end
    local first_line = stat_str:match("([^\n]+)")
    if not first_line then return nil end
    if first_line:sub(1, 3) == "cpu" then
        local parts = {}
        for p in first_line:gmatch("%d+") do
            table.insert(parts, tonumber(p))
        end
        -- /proc/stat cpu line: user nice system idle iowait irq softirq steal guest guest_nice
        if #parts >= 4 then
            local idle = (parts[4] or 0) + (parts[5] or 0)
            local non_idle = 0
            for i=1, #parts do
                if i ~= 4 and i ~= 5 then
                    non_idle = non_idle + parts[i]
                end
            end
            return { total = idle + non_idle, idle = idle, active = non_idle }
        end
    end
    return nil
end

local function get_net_stats()
    local dev_str = utils.readfile('/proc/net/dev')
    if not dev_str then return nil end
    local rx_bytes, tx_bytes = 0, 0
    for line in dev_str:gmatch("[^\n]+") do
        local colon_idx = line:find(':')
        if colon_idx then
            local data = line:sub(colon_idx + 1)
            local parts = {}
            for p in data:gmatch("%S+") do
                table.insert(parts, tonumber(p))
            end
            if #parts >= 9 then
                rx_bytes = rx_bytes + (parts[1] or 0)
                tx_bytes = tx_bytes + (parts[9] or 0)
            end
        end
    end
    return { rx = rx_bytes, tx = tx_bytes }
end

local function get_cpu_count()
    local stat_str = utils.readfile('/proc/stat')
    if not stat_str then return 1 end
    local count = 0
    for line in stat_str:gmatch("cpu%d+") do
        count = count + 1
    end
    return count > 0 and count or 1
end

function info.print_sysinfo()
    print("==================================================")
    print("              System Information                  ")
    print("==================================================")

    -- 1. Hostname
    local ok, _, host_out = utils.executeex('hostname')
    if ok and host_out then
        print(string.format("%-15s: %s", "Hostname", strip(host_out)))
    end

    -- 2. OS Release
    local os_name = "Unknown"
    local os_rel = config.read('/etc/os-release', { trim_quotes = true })
    if type(os_rel) == 'table' then
        os_name = os_rel.PRETTY_NAME or os_rel.NAME or os_name
        if type(os_name) == 'table' then
            os_name = table.concat(os_name, " ")
        end
        os_name = os_name:gsub('"', '')
    end
    print(string.format("%-15s: %s", "OS", os_name))

    -- 3. Kernel and Architecture
    local ok_uname, _, uname_out = utils.executeex('uname -srm')
    if ok_uname and uname_out then
        print(string.format("%-15s: %s", "Kernel/Arch", strip(uname_out)))
    end

    -- 4. Uptime
    local uptime_str = utils.readfile('/proc/uptime')
    if uptime_str then
        local uptime_sec = tonumber(utils.split(uptime_str)[1])
        if uptime_sec then
            local d = math.floor(uptime_sec / 86400)
            local h = math.floor((uptime_sec % 86400) / 3600)
            local m = math.floor((uptime_sec % 3600) / 60)
            
            local up_parts = {}
            if d > 0 then table.insert(up_parts, d .. " days") end
            if h > 0 then table.insert(up_parts, h .. " hours") end
            table.insert(up_parts, m .. " minutes")
            
            print(string.format("%-15s: %s", "Uptime", table.concat(up_parts, ", ")))
        end
    end

    -- 5. Memory
    local meminfo = config.read('/proc/meminfo', {
        keysep = ':',
        convert_numbers = function(s)
            s = s:gsub(' kB$', '')
            return tonumber(s)
        end
    })
    
    if type(meminfo) == 'table' and meminfo.MemTotal then
        local total_mb = math.floor(meminfo.MemTotal / 1024)
        local free_mb = math.floor((meminfo.MemAvailable or meminfo.MemFree or 0) / 1024)
        print(string.format("%-15s: %d MB Free / %d MB Total", "Memory", free_mb, total_mb))
    end

    -- 6. CPU & Network Utilization
    local cpu = get_cpu_stats()
    if cpu then
        local util = (cpu.active / cpu.total) * 100
        print(string.format("%-15s: %.1f%% (Avg since boot)", "CPU Util", util))
    end

    local loadavg_str = utils.readfile('/proc/loadavg')
    local cores = get_cpu_count()
    if loadavg_str then
        local loads = utils.split(loadavg_str)
        if #loads >= 3 then
            local l1 = tonumber(loads[1]) or 0
            local l5 = tonumber(loads[2]) or 0
            local l15 = tonumber(loads[3]) or 0
            print(string.format("%-15s: %.2f (%.1f%%), %.2f (%.1f%%), %.2f (%.1f%%)", 
                "Load Average", 
                l1, (l1/cores)*100, 
                l5, (l5/cores)*100, 
                l15, (l15/cores)*100))
        end
    end

    -- 6. Network Utilization (Average since boot)
    local net = get_net_stats()
    local uptime_str = utils.readfile('/proc/uptime')
    if net and uptime_str then
        local uptime_sec = tonumber(utils.split(uptime_str)[1])
        if uptime_sec and uptime_sec > 0 then
            print(string.format("%-15s: RX %.1f KB/s, TX %.1f KB/s (Avg since boot)", 
                "Network Util", 
                (net.rx / 1024) / uptime_sec, 
                (net.tx / 1024) / uptime_sec))
        end
    end

    print("==================================================")
end

-- Execute if run directly from the CLI
if arg and arg[0] and arg[0]:match("info%.lua$") then
    info.print_sysinfo()
end

return info