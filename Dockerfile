FROM steamcmd/steamcmd as steamcmd
RUN steamcmd +login anonymous +quit

FROM steamcmd AS server
ARG BUILDID
RUN mkdir /server; steamcmd +login anonymous +force_install_dir /server +app_update 896660 validate +quit
WORKDIR /server
ENV XDG_CONFIG_HOME=/saves
ENV LD_LIBRARY_PATH=./linux64:$LD_LIBRARY_PATH
ENV SteamAppId=892970
ENTRYPOINT [ "/server/valheim_server.x86_64" ]

EXPOSE 2456/udp 2457/udp 2458/udp
LABEL server.buildid ${BUILDID}