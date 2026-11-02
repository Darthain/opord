// Copyright (C) 2026 OPORD contributors
// BSD 3-Clause License. See LICENSE in this addon.

/*
*  SFSM_fnc_connectedHCs
*  Returns the owner IDs (> 2) of the connected headless clients.
*  Arguments: none. Return: ARRAY of NUMBER.
*  Server only. A HeadlessClient_F slot with a connected client is owned by that client.
*/
private _hcs = (entities "HeadlessClient_F") select {(owner _x) > 2};
_hcs apply {owner _x}
