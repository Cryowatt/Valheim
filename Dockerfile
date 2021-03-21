FROM steamcmd/steamcmd as server
ARG BUILDID
RUN mkdir /opt/valheim; steamcmd +login anonymous +force_install_dir /opt/valheim +app_update 896660 validate +quit
RUN steamcmd +login anonymous +force_install_dir /opt/valheim +app_status 896660 +quit | grep -q "BuildID ${BUILDID}"
WORKDIR /opt/valheim
ENV XDG_CONFIG_HOME=/saves
ENV LD_LIBRARY_PATH=./linux64:$LD_LIBRARY_PATH
ENV SteamAppId=892970
ENTRYPOINT [ "/opt/valheim/valheim_server.x86_64" ]
STOPSIGNAL SIGINT
EXPOSE 2456/udp 2457/udp 2458/udp
LABEL steam.buildid ${BUILDID}

FROM buildpack-deps:latest as mod_download
ARG BEPINEX_URL
RUN curl https://valheim.thunderstore.io/package/download/denikson/BepInExPack_Valheim/5.4.800/ -sLo BepInEx_unix.zip
RUN unzip -d /opt/bepinex ./BepInEx_unix.zip; ls /opt/bepinex; mv /opt/bepinex/BepInExPack_Valheim /opt/valheim; chmod +x /opt/valheim/*.sh

FROM server as mod
COPY --from=mod_download /opt/valheim /opt/valheim
ADD ./plugins/* /opt/valheim/BepInEx/plugins
ENV DOORSTOP_ENABLE=TRUE
ENV DOORSTOP_INVOKE_DLL_PATH=/opt/valheim/BepInEx/core/BepInEx.Preloader.dll
ENV DOORSTOP_CORLIB_OVERRIDE_PATH=/opt/valheim/unstripped_corlib

ENV LD_LIBRARY_PATH="/opt/valheim/doorstop_libs:$LD_LIBRARY_PATH"
ENV LD_PRELOAD="libdoorstop_x64.so:$LD_PRELOAD"