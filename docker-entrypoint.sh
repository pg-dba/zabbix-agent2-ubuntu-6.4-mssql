#!/usr/bin/env bash

# Rancher DNS
if [ ! -z "${DNSSERVER}" ]; then
echo "nameserver ${DNSSERVER}" > /etc/resolv.conf
fi

# cron timezone
if [ ! -z "${TZ}" ]; then
ln -snf /usr/share/zoneinfo/$TZ /etc/localtime
echo ${TZ} > /etc/timezone
fi

# odbc mssql
if [ ! -z "${ODBC_SRV}" ]; then
echo -e "[mssql]" > /etc/odbc.ini
echo "Driver = ODBC Driver 18 for SQL Server" >> /etc/odbc.ini
echo "Server =  ${ODBC_SRV}" >> /etc/odbc.ini
echo "Port = ${ODBC_PORT}" >> /etc/odbc.ini
echo "TrustServerCertificate = yes" >> /etc/odbc.ini
fi

exec "$@"
