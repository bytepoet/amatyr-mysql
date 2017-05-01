---
-- SQL specific API view
--
-- Copyright Tor Hveem <thveem> 2013-2014
--
--
local setmetatable = setmetatable
local ngx = ngx
local string = string
local cjson = require "cjson"
local mysql = require "resty.mysql"
local io = require "io"
local assert = assert
local conf

module(...)

local mt = { __index = _M }

if not conf then
    local f = assert(io.open(ngx.var.document_root .. "/etc/config.json", "r"))
    local c = f:read("*all")
    f:close()

    conf = cjson.decode(c)
end

local function dbreq(sql)
    local db, err = mysql:new()
    db:set_timeout(30000)
    local ok, err = db:connect(
        {
            host=conf.db.host,
            port=3306,
            database=conf.db.database,
            user=conf.db.user,
            password=conf.db.password
        })
    if not ok then
        ngx.say(err)
    end
    --ngx.log(ngx.ERR, '___ SQL ___'..sql)
    local res, err = db:query(sql)
    if not res then
        ngx.log(ngx.ERR, 'Failed SQL query:' ..sql)
        res = {error=err}
    end
    db:set_keepalive(0,10)
    return cjson.encode(res)
end

-- Translate front end column names to back end column names
local function column(key)
    return conf.db.columns[key]
end

function max(match)
    local key = ngx.req.get_uri_args()['key']
    if not key then ngx.exit(403) end
    -- Make sure valid request, only accept plain lowercase ascii string for key name
    local keytest = ngx.re.match(key, '[a-z]+', 'oj')
    if not keytest then ngx.exit(403) end

    local sql = [[
        SELECT
            DAY(FROM_UNIXTIME(datetime)) AS datetime,
            MAX(]]..key..[[) AS ]]..key..[[
        FROM ]]..conf.db.table..[[
        WHERE YEAR(FROM_UNIXTIME(dateTime)) < 2013
        GROUP BY 1
    ]]

    return dbreq(sql)
end

-- Latest record in db
function now(match)
    return dbreq([[
    SELECT *, FROM_UNIXTIME(datetime) as datetime,
    (
        SELECT SUM(rain)
        FROM ]]..conf.db.table..[[
        WHERE FROM_UNIXTIME(datetime) >= CURRENT_DATE
    )
    AS dayrain
    FROM ]]..conf.db.table..[[
    ORDER BY datetime DESC LIMIT 1]])
end

-- Last 60 samples from db
function recent(match)
    return dbreq([[SELECT
    *, DAY(FROM_UNIXTIME(datetime)) as day, FROM_UNIXTIME(datetime) as datetime,
    (
        SELECT SUM(b.rain)
        FROM (
            SELECT DAY(FROM_UNIXTIME(datetime)) AS bday, rain
            FROM ]]..conf.db.table..[[
            ORDER BY datetime DESC
            LIMIT 60
        ) AS b
        WHERE day=bday
    ) AS dayrain
    FROM ]]..conf.db.table..[[
    ORDER BY datetime DESC 
    LIMIT 60]])
end

-- Helper function to get a start argument and return SQL constrains
local function getDateConstrains(startarg, interval)
    local where = ''
    local andwhere = ''
    if startarg then
        local start
        local endpart = "1 year"
        if string.upper(startarg) == 'TODAY' then
            start = "CURRENT_DATE"
            endpart = "1 DAY"
        elseif string.lower(startarg) == 'yesterday' then
            start = "CURRENT_DATE - INTERVAl 1 day"
            endpart = '1 day'
        elseif string.upper(startarg) == '3DAY' then
            start = "CURRENT_DATE - INTERVAL 3 day"
            endpart = '3 day'
        elseif string.upper(startarg) == 'WEEK' then
            start = "CURRENT_DATE - INTERVAL 1 week"
            endpart = '1 week'
        elseif string.upper(startarg) == '7DAYS' then
            start = "CURRENT_DATE - INTERVAL 1 WEEK"
            endpart = '1 WEEK'
        elseif string.upper(startarg) == 'MONTH' then
            -- old used this month, new version uses last 30 days
            --start = "to_date( to_char(current_date,'yyyy-MM') || '-01','yyyy-mm-dd')"
            start = "CURRENT_DATE - INTERVAL 1 MONTH"
            endpart = "1 MONTH"
        elseif string.upper(startarg) == 'YEAR' then
            start = "CURRENT_DATE - INTERVAL 1 YEAR"
            endpart = "1 year"
        elseif string.upper(startarg) == 'ALL' then
            start = "DATE '1900-01-01'" -- Should be old enough :-)
            endpart = "200 year"
        else
            start = "DATE '" .. startarg .. "-01-01'"
        end
        -- use interval if provided, if not use the default endpart
        if not interval then
            interval = endpart
        end

        local wherepart = [[
        (
            FROM_UNIXTIME(dateTime) BETWEEN ]]..start..[[
            AND
            ]]..start..[[ + INTERVAL ]]..endpart..[[
        )
        ]]
        where = 'WHERE ' .. wherepart
        andwhere = 'AND ' .. wherepart
    end
    return where, andwhere
end

-- Function to return extremeties from database, min/maxes for different time intervals
function record(match)

    local key = match[1]
    local func = string.upper(match[2])
    local where, andwhere = getDateConstrains(ngx.req.get_uri_args()['start'])
    local sql

    -- Special handling for rain since it needs a sum
    if key == 'dayrain' then
        -- Not valid with any other value than max
        sql = [[
        SELECT
        DISTINCT FROM_UNIXTIME(datetime) AS datetime,
        SUM(rain) AS dayrain
        FROM ]]..conf.db.table..[[
        ]]..where..[[
        ORDER BY dayrain DESC
        LIMIT 1
        ]]
    elseif func == 'SUM' then
        -- The SUM part doesn't need the datetime of the record since the datetime is effectively over the whole scope
        sql = [[
            SELECT
            SUM(]]..key..[[) AS ]]..key..[[
            FROM ]]..conf.db.table..[[
            ]]..where..[[
        ]]
    else
        sql = [[
        SELECT
            FROM_UNIXTIME(datetime) as datetime,
            TIMEDIFF(NOW(), FROM_UNIXTIME(datetime)) AS age,
            ]]..key..[[
        FROM ]]..conf.db.table..[[
        WHERE
        ]]..key..[[ =
        (
            SELECT
                ]]..func..[[(]]..key..[[)
            FROM ]]..conf.db.table..[[
            ]]..where..[[
            LIMIT 1
        )
        ]]..andwhere..[[
        LIMIT 1
        ]]
    end

    return dbreq(sql)
end

--- Return weather data by hour, week, month, year, whatever..
function by_dateunit(match)
    local unit = 'hour'
    if match[1] then
        if match[1] == 'month' then
            unit = 'day'
        end
    elseif ngx.req.get_uri_args()['start'] == 'month' then
        unit = 'day'
    end
    -- get the date constraints
    local where, andwhere = getDateConstrains(ngx.req.get_uri_args()['start'])
    local sql = dbreq([[
    SELECT
        ]]..unit..[[(FROM_UNIXTIME(datetime)) AS datetime,
        AVG(outTemp) as outTemp,
        MIN(outTemp) as tempmin,
        MAX(outTemp) as tempmax,
        AVG(dewpoint) as dewpoint,
        AVG(rain) as rain,
        MAX(b.dayrain) as dayrain,
        AVG(windSpeed) as windSpeed,
        MAX(windGust) as windGust,
        AVG(windDir) as windDir,
        AVG(barometer) as barometer,
        AVG(outHumidity) as outHumidity,
        AVG(inTemp) as inTemp,
        AVG(inHumidity) as inHumidity,
        AVG(heatindex) as heatindex,
        AVG(windchill) as windchill
    FROM ]]..conf.db.table..[[ as a
    LEFT OUTER JOIN (
        SELECT DISTINCT
            ]]..unit..[[(FROM_UNIXTIME(datetime)) AS unit,
            (
                SELECT SUM(rain)
                FROM (
                    SELECT DISTINCT ]]..unit..[[(FROM_UNIXTIME(datetime)) AS cunit, rain
                    FROM ]]..conf.db.table..[[ ]]..where..[[
                    ORDER BY 1
                ) as c
                WHERE unit=cunit
            ) AS dayrain
        FROM ]]..conf.db.table..[[ ]]..where..[[
        ORDER BY 1
    ) AS b
    ON a.datetime = b.unit
    ]]..where..[[
    GROUP BY 1
    ORDER BY datetime
    ]])
    return sql
end

function day(match)
    local where, andwhere = getDateConstrains(ngx.req.get_uri_args()['start'])
    local sql = dbreq([[
    SET @dr=0;
    SELECT
        *, @dr:=@dr+rain AS dayrain
    FROM ]]..conf.db.table..[[
    ]]..where..[[
    ORDER BY datetime
    ]])
    return sql
end

function year(match)
    -- This function generates stats into a new table
    -- which is updated max once a day
    -- first it checks the latest record in the stats table
    -- and if latest date is older than today
    -- it will recreate the table
    local year = match[1]
    local syear = year .. '-01-01'
    local where = [[
        WHERE FROM_UNIXTIME(datetime) BETWEEN DATE ']]..syear..[['
        AND DATE ']]..syear..[[' + INTERVAL 1 year
    ]]

    local needsupdate = cjson.decode(dbreq[[
        SELECT
        MAX(datetime) < (NOW() - INTERVAL 24 hour) AS needsupdate
        FROM days
    ]])
    if needsupdate == ngx.null or needsupdate[1] == nil or needsupdate.error ~= nil then
        needsupdate = true
    else
        if needsupdate[1]['needsupdate'] == 't' then
            needsupdate = true
        else
            needsupdate = false
        end
    end
    if needsupdate then
        -- Remove existing cache. This could be improved to only add missing data
        dbreq('DROP TABLE days')
        -- Create new cached table
        local gendays = dbreq([[
        CREATE TABLE days AS
            SELECT
                DAY(FROM_UNIXTIME(datetime)) AS datetime,
                AVG(outTemp) as outTemp,
                MIN(outTemp) as tempmin,
                MAX(outTemp) as tempmax,
                AVG(dewpoint) as dewpoint,
                AVG(rain) as rain,
                MAX(b.dayrain) as dayrain,
                AVG(windSpeed) as windSpeed,
                MAX(windGust) as windGust,
                AVG(windDir) as windDir,
                AVG(barometer) as barometer,
                AVG(outHumidity) as outHumidity,
                AVG(inTemp) as inTemp,
                AVG(inHumidity) as inHumidity,
                AVG(heatindex) as heatindex,
                AVG(windchill) as windchill
            FROM ]]..conf.db.table..[[ AS a
            LEFT OUTER JOIN
            (
                SELECT
                    DISTINCT DAY(FROM_UNIXTIME(datetime)) AS hour,
                    SUM(rain) AS dayrain
                    FROM ]]..conf.db.table..[[ ORDER BY 1
            ) AS b
            ON a.datetime = b.hour
            GROUP BY 1
            ORDER BY datetime
            ]])
    end
    local sql = [[
        SELECT *
        FROM days
        ]]..where
    return dbreq(sql)
end

function windhist(match)
    local where, andwhere = getDateConstrains(ngx.req.get_uri_args()['start'])
    return dbreq([[
        SELECT count(*), ((windDir/10)*10)+0 as d, avg(windSpeed)*1.94384449 as avg
        FROM ]]..conf.db.table..[[
        ]]..where..[[
        GROUP BY 2
        ORDER BY 2
    ]])
end

local class_mt = {
    -- to prevent use of casual module global variables
    __newindex = function (table, key, val)
        ngx.log(ngx.ERR, 'attempt to write to undeclared variable "' .. key .. '"')
    end
}

setmetatable(_M, class_mt)