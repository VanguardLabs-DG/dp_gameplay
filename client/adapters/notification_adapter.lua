local NotificationAdapter = {}

function NotificationAdapter.notify(title, description, notifType)
    lib.notify({
        title = title or 'Distrito Paulista',
        description = description,
        type = notifType or 'inform',
        position = 'top-right'
    })
end

function NotificationAdapter.showTextUI(text)
    lib.showTextUI(text, { position = 'top-center' })
end

function NotificationAdapter.hideTextUI()
    lib.hideTextUI()
end

function NotificationAdapter.confirmDialog(header, content)
    local alert = lib.alertDialog({
        header = header,
        content = content,
        centered = true,
        cancel = true
    })
    return alert == 'confirm'
end

_G.NotificationAdapter = NotificationAdapter
return NotificationAdapter
