local DiscordAdapter = {}

function DiscordAdapter.sendLog(channel, title, description, color, fields)
    if not vanguard or not vanguard.discord or not vanguard.discord.log then
        return
    end

    local embed = {
        title = title or 'Log do Servidor',
        description = description or '',
        color = color or 15158332
    }

    if fields and #fields > 0 then
        embed.fields = fields
    end

    vanguard.discord.log({
        channel = channel or 'default',
        priority = 'normal',
        embed = embed
    })
end

_G.DiscordAdapter = DiscordAdapter
return DiscordAdapter
