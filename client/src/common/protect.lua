-- From http://andrejs-cainikovs.blogspot.ru/2009/05/lua-constants.html
-- "By Lua's nature, it is not possible to create constants. There is a workaround, though, using metatables"

function protect(tbl)
    return setmetatable({}, {
        __index = tbl,
        __newindex = function(t, key, value)
            error("attempting to change constant " ..
                   tostring(key) .. " to " .. tostring(value), 2)
        end
    })
end

