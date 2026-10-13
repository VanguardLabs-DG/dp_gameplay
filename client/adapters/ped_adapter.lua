local PedAdapter = {}

function PedAdapter.getPed()
    return cache.ped or PlayerPedId()
end

function PedAdapter.playAnim(ped, dict, anim, blendIn, blendOut, duration, flag, playbackRate)
    lib.requestAnimDict(dict)
    TaskPlayAnim(ped, dict, anim, blendIn or 8.0, blendOut or -8.0, duration or -1, flag or 49, playbackRate or 0.0, false, false, false)
end

function PedAdapter.stopAnim(ped, dict, anim)
    StopAnimTask(ped, dict, anim, 3.0)
end

function PedAdapter.clearTasks(ped)
    ClearPedTasks(ped)
end

function PedAdapter.setRagdoll(ped, time1, time2, ragdollType)
    SetPedToRagdoll(ped, time1 or 2000, time2 or 2000, ragdollType or 0, false, false, false)
end

function PedAdapter.setRagdollWithFall(ped, time1, time2, fwdVector)
    SetPedToRagdollWithFall(ped, time1 or 2500, time2 or 1500, 0, fwdVector.x, fwdVector.y, fwdVector.z, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
end

function PedAdapter.setMovementClipset(ped, animSet)
    lib.requestAnimSet(animSet)
    SetPedMovementClipset(ped, animSet, 0.25)
end

function PedAdapter.resetMovementClipset(ped)
    ResetPedMovementClipset(ped, 0.25)
    ResetPedStrafeClipset(ped)
    ResetPedWeaponMovementClipset(ped)
end

function PedAdapter.getClosestPlayer(maxDist)
    local coords = GetEntityCoords(cache.ped or PlayerPedId())
    return lib.getClosestPlayer(coords, maxDist or 2.5, false)
end

function PedAdapter.attachEntityToEntity(entity, target, boneIndex, x, y, z, rx, ry, rz)
    AttachEntityToEntity(entity, target, boneIndex, x, y, z, rx, ry, rz, true, false, false, false, 2, true)
end

function PedAdapter.detachEntity(entity)
    DetachEntity(entity, true, true)
end

function PedAdapter.isDeadOrDown(ped)
    if not DoesEntityExist(ped) then return true end
    local entState = Entity(ped).state
    if entState.isDead or entState.dead or entState.bodydrag_down or entState['qbx_medical:deathState'] then
        return true
    end
    return IsPedDeadOrDying(ped, true) or (GetEntityHealth(ped) <= 100)
end

_G.PedAdapter = PedAdapter
return PedAdapter
