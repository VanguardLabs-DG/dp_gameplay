local SlingCamera = {}

local activeCam = nil
local isOrbiting = false
local camDistance = 1.6
local camPitch = 5.0
local camHeading = 0.0

function SlingCamera.isActive()
    return isOrbiting
end

function SlingCamera.start(targetPed)
    if isOrbiting and activeCam then return end
    targetPed = targetPed or PlayerPedId()

    local pCoords = GetEntityCoords(targetPed)
    camHeading = GetEntityHeading(targetPed) + 180.0
    camPitch = 5.0
    camDistance = 1.5

    activeCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamActive(activeCam, true)
    RenderScriptCams(true, true, 500, true, true)

    isOrbiting = true

    CreateThread(function()
        while isOrbiting and activeCam do
            Wait(0)
            local ped = targetPed or PlayerPedId()
            if not DoesEntityExist(ped) or IsEntityDead(ped) then
                SlingCamera.stop()
                break
            end

            -- Desabilita locomoção para permitir ajuste limpo
            DisableControlAction(0, 30, true) -- D / A
            DisableControlAction(0, 31, true) -- W / S
            DisableControlAction(0, 21, true) -- Sprint
            DisableControlAction(0, 22, true) -- Jump
            DisableControlAction(0, 24, true) -- Attack
            DisableControlAction(0, 25, true) -- Aim
            DisableControlAction(0, 1, true)  -- Look LR normal
            DisableControlAction(0, 2, true)  -- Look UD normal

            -- Mouse Orbit (Botão direito ou movimento livre)
            local mouseX = GetDisabledControlNormal(0, 1)
            local mouseY = GetDisabledControlNormal(0, 2)

            if math.abs(mouseX) > 0.001 then
                camHeading = (camHeading - (mouseX * 8.0)) % 360.0
            end
            if math.abs(mouseY) > 0.001 then
                camPitch = math.max(-40.0, math.min(60.0, camPitch - (mouseY * 8.0)))
            end

            -- Scroll Zoom (Controles 14 / 15 ou 241 / 242)
            if IsControlJustPressed(0, 241) or IsDisabledControlJustPressed(0, 241) then
                camDistance = math.max(0.7, camDistance - 0.15)
            elseif IsControlJustPressed(0, 242) or IsDisabledControlJustPressed(0, 242) then
                camDistance = math.min(2.8, camDistance + 0.15)
            end

            -- Calcula posição orbital esférica ao redor do tronco do ped
            local spineCoords = GetPedBoneCoords(ped, 24818, 0.0, 0.0, 0.0)
            local radHeading = math.rad(camHeading)
            local radPitch = math.rad(camPitch)

            local cx = spineCoords.x + (camDistance * math.cos(radPitch) * math.sin(radHeading))
            local cy = spineCoords.y + (camDistance * math.cos(radPitch) * math.cos(radHeading))
            local cz = spineCoords.z + (camDistance * math.sin(radPitch))

            SetCamCoord(activeCam, cx, cy, cz)
            PointCamAtCoord(activeCam, spineCoords.x, spineCoords.y, spineCoords.z)
        end
    end)
end

function SlingCamera.stop()
    if not isOrbiting then return end
    isOrbiting = false

    if activeCam and DoesCamExist(activeCam) then
        SetCamActive(activeCam, false)
        RenderScriptCams(false, true, 400, true, true)
        DestroyCam(activeCam, false)
        activeCam = nil
    end
end

_G.SlingCamera = SlingCamera
return SlingCamera
