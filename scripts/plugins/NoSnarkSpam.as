array<float> g_rgflLastWeaponSwitchTime;
array<EHandle> g_rghPreviousFramePlayerWeapon;
array<bool> g_rgbHasTimedOutWeaponSwitching;
array<CScheduledFunction@> g_rgpfnRemoveExclusiveHold;
array<CScheduledFunction@> g_rgpfnWatchdog;

void PluginInit() {
    g_Module.ScriptInfo.SetAuthor("xWhitey");
    g_Module.ScriptInfo.SetContactInfo("@tyabus at Discord");
    
    g_rgflLastWeaponSwitchTime.resize(0);
    g_rgflLastWeaponSwitchTime.resize(33);
    g_rghPreviousFramePlayerWeapon.resize(0);
    g_rghPreviousFramePlayerWeapon.resize(33);
    g_rgbHasTimedOutWeaponSwitching.resize(0);
    g_rgbHasTimedOutWeaponSwitching.resize(33);
    g_rgpfnRemoveExclusiveHold.resize(0);
    g_rgpfnWatchdog.resize(0);
    g_rgpfnWatchdog.resize(33);
    
    for (int idx = 1; idx <= g_Engine.maxClients; ++idx) {
        @g_rgpfnWatchdog[idx] = g_Scheduler.SetTimeout("Watchdog", 0.1f, idx);
    }
}

void MapInit() {
    g_rgflLastWeaponSwitchTime.resize(0);
    g_rgflLastWeaponSwitchTime.resize(33);
    g_rghPreviousFramePlayerWeapon.resize(0);
    g_rghPreviousFramePlayerWeapon.resize(33);
    g_rgbHasTimedOutWeaponSwitching.resize(0);
    g_rgbHasTimedOutWeaponSwitching.resize(33);
    g_rgpfnRemoveExclusiveHold.resize(0);
    
    for (uint idx = 0; idx < g_rgpfnWatchdog.length(); idx++) {
        CScheduledFunction@ pfnSched = @g_rgpfnWatchdog[idx];
        if (pfnSched !is null && !pfnSched.HasBeenRemoved()) {
            g_Scheduler.RemoveTimer(pfnSched);
        }
    }
    
    g_rgpfnWatchdog.resize(0);
    g_rgpfnWatchdog.resize(33);
    
    for (int idx = 1; idx <= g_Engine.maxClients; ++idx) {
        @g_rgpfnWatchdog[idx] = g_Scheduler.SetTimeout("Watchdog", 0.1f, idx);
    }
}

//We actually won't be able to catch the moment when the player switches their weapon and speedhacks if wootguy's anticheat is installed on the server
//Because it cancels PlayerPreThink and PlayerPostThink events if player's speedhack state is SPEEDHACK_FAST, so we need to use schedulers instead.
void Watchdog(int _PlayerIdx) {
    CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(_PlayerIdx);
    if (pPlayer is null || !pPlayer.IsConnected()) {
        @g_rgpfnWatchdog[_PlayerIdx] = g_Scheduler.SetTimeout("Watchdog", 0.0f, _PlayerIdx);
        return;
    }
    
    EHandle hPrevFrameWeapon = g_rghPreviousFramePlayerWeapon[_PlayerIdx];
    if (!hPrevFrameWeapon.IsValid()) {
        EHandle hActiveItem = pPlayer.m_hActiveItem;
        if (!hActiveItem.IsValid()) {
            @g_rgpfnWatchdog[_PlayerIdx] = g_Scheduler.SetTimeout("Watchdog", 0.0f, _PlayerIdx);
            return;
        }
        g_rghPreviousFramePlayerWeapon[_PlayerIdx] = hActiveItem;
        
        @g_rgpfnWatchdog[_PlayerIdx] = g_Scheduler.SetTimeout("Watchdog", 0.0f, _PlayerIdx);
        return;
    }
    EHandle hCurrentActiveItem = pPlayer.m_hActiveItem;
    if (!hCurrentActiveItem.IsValid() && hPrevFrameWeapon.IsValid()) {
        g_rghPreviousFramePlayerWeapon[_PlayerIdx] = null;
        @g_rgpfnWatchdog[_PlayerIdx] = g_Scheduler.SetTimeout("Watchdog", 0.0f, _PlayerIdx);
        return;
    }
    CBaseEntity@ pCurrentActiveItemEntity = hCurrentActiveItem.GetEntity();
    CBaseEntity@ pPreviousActiveItemEntity = hPrevFrameWeapon.GetEntity();
    CBasePlayerItem@ pCurrentActiveItem = cast<CBasePlayerItem@>(pCurrentActiveItemEntity);
    CBasePlayerItem@ pPreviousActiveItem = cast<CBasePlayerItem@>(pPreviousActiveItemEntity);
    if (pCurrentActiveItem is null || pPreviousActiveItem is null) {
        @g_rgpfnWatchdog[_PlayerIdx] = g_Scheduler.SetTimeout("Watchdog", 0.0f, _PlayerIdx);
        return;
    }
    if (g_rgbHasTimedOutWeaponSwitching[_PlayerIdx] && (g_Engine.time - g_rgflLastWeaponSwitchTime[_PlayerIdx] > 0.5f)) {
        g_rgbHasTimedOutWeaponSwitching[_PlayerIdx] = false;
        pCurrentActiveItem.m_bExclusiveHold = false;
        @g_rgpfnWatchdog[_PlayerIdx] = g_Scheduler.SetTimeout("Watchdog", 0.0f, _PlayerIdx);
        return;
    }
    
    string szCurrentClassname = pCurrentActiveItem.GetClassname();
    string szPreviousClassname = pPreviousActiveItem.GetClassname();
    if (pCurrentActiveItem !is pPreviousActiveItem || szCurrentClassname != szPreviousClassname) {
        if (szCurrentClassname == "weapon_snark" && szPreviousClassname != "weapon_snark") {
            if (g_Engine.time - g_rgflLastWeaponSwitchTime[_PlayerIdx] < 0.5f && !g_rgbHasTimedOutWeaponSwitching[_PlayerIdx]) {
                pCurrentActiveItem.m_bExclusiveHold = true;
                g_rgbHasTimedOutWeaponSwitching[_PlayerIdx] = true;
                g_rgpfnRemoveExclusiveHold.insertLast(g_Scheduler.SetTimeout("RemoveExclusiveHold", 0.5f, EHandle(pCurrentActiveItem)));
            }
        }
        g_rgflLastWeaponSwitchTime[_PlayerIdx] = g_Engine.time;
    }
    g_rghPreviousFramePlayerWeapon[_PlayerIdx] = EHandle(pCurrentActiveItem);
    @g_rgpfnWatchdog[_PlayerIdx] = g_Scheduler.SetTimeout("Watchdog", 0.0f, _PlayerIdx);
}

void RemoveExclusiveHold(EHandle _Item) {
    if (!_Item.IsValid())
        return;
    CBaseEntity@ pItemEntity = _Item.GetEntity();
    CBasePlayerItem@ pItem = cast<CBasePlayerItem@>(pItemEntity);
    pItem.m_bExclusiveHold = false;
}
