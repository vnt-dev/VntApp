package com.rustvnt.vntapp;

import com.vnt.VntApi;
import java.util.Collections;
import java.util.List;

final class VntState {
    enum Status { STOPPED, STARTING, RUNNING, ERROR, STOPPING }

    final Status status;
    final String profileId;
    final String profileName;
    final String ip;
    final String message;
    final List<VntApi.ClientInfo> clients;
    final List<VntApi.ServerInfo> servers;
    final List<VntApi.RouteInfo> routes;
    final VntApi.NatInfo nat;
    final VntApi.NetworkInfo network;

    VntState(Status status, String profileId, String profileName, String ip, String message,
             List<VntApi.ClientInfo> clients, List<VntApi.ServerInfo> servers,
             List<VntApi.RouteInfo> routes, VntApi.NatInfo nat, VntApi.NetworkInfo network) {
        this.status = status;
        this.profileId = profileId;
        this.profileName = profileName;
        this.ip = ip;
        this.message = message;
        this.clients = clients == null ? Collections.emptyList() : clients;
        this.servers = servers == null ? Collections.emptyList() : servers;
        this.routes = routes == null ? Collections.emptyList() : routes;
        this.nat = nat;
        this.network = network;
    }

    static VntState stopped() {
        return new VntState(Status.STOPPED, null, null, null, "全部实例已停止", null, null, null, null, null);
    }
}
