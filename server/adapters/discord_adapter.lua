local DiscordAdapter = {}

function DiscordAdapter.sendLog(channel, title, description, color, fields)
    if not vanguard or not vanguard.discord or not vanguard.discord.log then
        -- Fallback seguro caso vanguard_lib discord queue não esteja carregada
        return
    end

    vanguard.discord.log({
        channel = channel or 'default',
        title = title or 'Log do Servidor',
        description = description or '',
        color = color or 15158332,
        fields = fields or {}
    })
end

_G.DiscordAdapter = DiscordAdapter
return DiscordAdapter
