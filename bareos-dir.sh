#!/bin/bash

 : "${DBDRIVER:?DBDRIVER needs to be set}"
 : "${DBADDRESS:?DBADDRESS needs to be set}"
 : "${DBPORT:?DBPORT needs to be set}"
 : "${DBNAME:?DBNAME needs to be set}"
 : "${DBUSER:?DBUSER needs to be set}"
 : "${DBPASSWORD:?DBPASSWORD needs to be set}"
 : "${MAILUSER:?MAILUSER needs to be set}"
 : "${MAILHUB:?MAILHUB needs to be set}"
 : "${MAILDOMAIN:?MAILDOMAIN needs to be set}"
 : "${MAILHOSTNAME:?MAILHOSTNAME needs to be set}"

daemon_user=bareos
daemon_group=bareos
DEFCONFIGDIR="/usr/lib/bareos/defaultconfigs/bareos-dir.d/"
CONFIGDIR="/etc/bareos/bareos-dir.d/"

/usr/lib/bareos/scripts/bareos-config deploy_config "$DEFCONFIGDIR" "$CONFIGDIR"
for dir in /etc/bareos/bareos-dir-export/ /etc/bareos/bareos-dir-export/client ; do
 chown ${daemon_user}:${daemon_group} "$dir"
 chmod 750 "$dir"
done

DEFCONFIGDIR="/usr/lib/bareos/defaultconfigs"
CONFIG="bconsole.conf"
TARGET="/etc/bareos/${CONFIG}"
if [ ! -f "$TARGET" ]; then
  cat ${DEFCONFIGDIR}/${CONFIG} > ${TARGET}
  /usr/lib/bareos/scripts/bareos-config initialize_local_hostname
  /usr/lib/bareos/scripts/bareos-config initialize_passwords
  chown root:${daemon_group} $TARGET
  chmod 640 $TARGET
fi

cat << EOF > /etc/bareos/bareos-dir.d/catalog/MyCatalog.conf
Catalog {
  Name = MyCatalog
  dbdriver = "$DBDRIVER"
  dbaddress = "$DBADDRESS"
  dbport = "$DBPORT"
  dbname = "$DBNAME"
  dbuser = "$DBUSER"
  dbpassword = "$DBPASSWORD"
}
EOF

cat << EOF > /etc/ssmtp/ssmtp.conf
root=$MAILUSER
mailhub=$MAILHUB
rewriteDomain=$MAILDOMAIN
hostname=$MAILHOSTNAME
FromLineOverride=NO
EOF

if [ ! -f $CONFIGDIR/.dbready ] ; then
 until mysql -B -D $DBNAME -h $DBADDRESS -P $DBPORT -u $DBUSER -p$DBPASSWORD -e exit ; do
  sleep 5s;
 done
 mysql -B -D $DBNAME -h $DBADDRESS -P $DBPORT -u $DBUSER -p$DBPASSWORD < /usr/share/dbconfig-common/data/bareos-database-common/install/mysql && touch $CONFIGDIR/.dbready
fi

exec /usr/sbin/bareos-dir -f
