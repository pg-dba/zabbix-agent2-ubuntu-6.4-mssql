FROM zabbix/zabbix-agent2:ubuntu-6.4.12
#FROM zabbix/zabbix-agent2:ubuntu-6.4-latest

USER root

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get -y install curl lsb-release gnupg2 && \
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg && \
    curl https://packages.microsoft.com/config/debian/12/prod.list > /etc/apt/sources.list.d/mssql-release.list && \
    apt-get update && \
    ACCEPT_EULA=Y apt-get install -y msodbcsql18 mssql-tools18 && \
    chmod 777 /etc/odbc.ini && \
    apt-get -y install iputils-ping fping dnsutils telnet && \
    cd /usr/sbin; ln -s /usr/bin/fping && \
    chown root:zabbix /usr/bin/fping && \
    chmod u+s /usr/bin/fping && \
    mkdir -p /etc/zabbix/zabbix_agentd.d/query && \
    sed -i 's/# Plugins.PostgreSQL.CustomQueriesPath=/Plugins.PostgreSQL.CustomQueriesPath=\/etc\/zabbix\/zabbix_agentd.d\/query/' /etc/zabbix/zabbix_agent2.d/plugins.d/postgresql.conf && \
    echo 'SELECT COUNT(*) as result FROM pg_ls_waldir() WHERE name ~ '"'"'^[0-9A-F]{24}$'"'"';' > /etc/zabbix/zabbix_agentd.d/query/walcount.sql && \
    echo 'SELECT (extract (epoch FROM ((x - n)::interval)))::integer as result FROM (SELECT min(modification) as n, max(modification) as x  FROM pg_ls_waldir() WHERE name ~ '"'"'^[0-9A-F]{24}$'"'"') tmp;' > /etc/zabbix/zabbix_agentd.d/query/walinterval.sql && \
    echo 'SELECT COUNT(*) as result FROM pg_replication_slots;' > /etc/zabbix/zabbix_agentd.d/query/rslot.sql && \
    echo "SELECT COUNT(*) as result FROM pg_stat_activity WHERE state not in ('idle in transaction', 'idle in transaction (aborted)', 'idle') AND (current_timestamp - query_start > \$1 OR current_timestamp - xact_start > \$1) AND backend_type = 'client backend';" > /etc/zabbix/zabbix_agentd.d/query/longquery.sql && \
    echo "SELECT CASE setting WHEN 'off' THEN 0 WHEN 'on' THEN 1 WHEN 'always' THEN 2 END as result FROM pg_catalog.pg_settings WHERE name = 'archive_mode';" > /etc/zabbix/zabbix_agentd.d/query/archivemode.sql && \
    echo 'SELECT CASE WHEN pg_is_in_recovery() THEN pg_is_wal_replay_paused()::integer ELSE 0 END as result;' > /etc/zabbix/zabbix_agentd.d/query/rpause.sql && \
    echo "SELECT string_agg(s,'') as result FROM (SELECT s FROM (SELECT 1 as n, 0 as seqno, '<TABLE>' as s UNION SELECT 2 as n, 0 as seqno, '<TR><TH>seqno</TH><TH>name</TH><TH>setting</TH><TH>applied</TH><TH>sourcefile</TH></TR>' as s UNION SELECT 3 as n, seqno, '<TR><TD>' || seqno || '</TD><TD>' || name || '</TD><TD>' || setting || '</TD><TD>' || applied || '</TD><TD>' || REPLACE(sourcefile,'/var/lib/postgresql/data/','') || '</TD></TR>' as s FROM pg_catalog.pg_file_settings UNION SELECT 4 as n, 0 as seqno, '</TABLE>' as s ) tmp ORDER BY n, seqno) res;" > /etc/zabbix/zabbix_agentd.d/query/pgconfig.sql && \
    echo "SELECT CEILING( sum(stat.size) / 1024. / 1024. ) as result FROM public.zbx_ls_dir_log() AS logs CROSS JOIN LATERAL public.zbx_stat_log_file(logs) AS stat;" > /etc/zabbix/zabbix_agentd.d/query/logsize.sql && \
    chown -R zabbix:zabbix /etc/zabbix && \
    apt-get clean all && \
    unset DEBIAN_FRONTEND

RUN touch /etc/odbc.ini && \
    chmod 600 /etc/odbc.ini && \
    chown zabbix:zabbix /etc/odbc.ini

USER zabbix

RUN echo 'alias nocomments="sed -e :a -re '"'"'s/<\!--.*?-->//g;/<\!--/N;//ba'"'"' | sed -e :a -re '"'"'s/\/\*.*?\*\///g;/\/\*/N;//ba'"'"' | grep -v -P '"'"'^\s*(#|;|--|//|$)'"'"'"' >> ~/.bashrc
RUN echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> ~/.bashrc

RUN echo 'echo "[mssql]" >> /etc/odbc.ini' >> ~/.bashrc && \
    echo 'echo "Driver = ODBC Driver 18 for SQL Server" >> /etc/odbc.ini' >> ~/.bashrc && \
    echo 'echo "Server =  ${ODBC_SRV}" >> /etc/odbc.ini' >> ~/.bashrc && \
    echo 'echo "Port = ${ODBC_PORT}" >> /etc/odbc.ini' >> ~/.bashrc && \
    echo 'echo "TrustServerCertificate = yes" >> /etc/odbc.ini' >> ~/.bashrc

WORKDIR /etc/zabbix
