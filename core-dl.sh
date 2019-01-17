DRUPAL_ROOT_ARG=$1
VERSION_TO_DOWNLOAD=$2

# Abort if DRUPAL_ROOT_ARG is empty.
if [ -z $DRUPAL_ROOT_ARG ]; then
  echo "No module name specified. Aborting dl.sh."
  exit 1;
fi

DRUPAL_ROOT=$(readlink --canonicalize $DRUPAL_ROOT_ARG)
SYSTEM_INFO_FILE=$DRUPAL_ROOT/modules/system/system.info

# Abort if DRUPAL_ROOT does not exist.
if [ ! -d $DRUPAL_ROOT ]; then
  echo "$DRUPAL_ROOT does not exist. Aborting dl.sh."
  exit 1;
fi

# Abort if DRUPAL_ROOT is not a Drupal directory.
if [ ! -f $SYSTEM_INFO_FILE ]; then
  echo "$SYSTEM_INFO_FILE does not exist. Aborting dl.sh."
  exit 1;
fi

# Abort if VERSION_TO_DOWNLOAD is empty or invalid.
if [ -z $VERSION_TO_DOWNLOAD ]; then
  echo "No core version specified. Aborting dl.sh."
  exit 1;
fi

# Download project in desired version in /tmp.
if [ -d /tmp/drush-dl ]; then
  rm -r /tmp/drush-dl
fi
mkdir /tmp/drush-dl
cd /tmp/drush-dl

drush dl -y --drupal-project-rename drupal-$VERSION_TO_DOWNLOAD

if [ ! -d /tmp/drush-dl/drupal ]; then
  echo "Failed to download drupal-$VERSION_TO_DOWNLOAD"
  exit 2;
fi

# Replace the (possibly) modified module versions.
cd $DRUPAL_ROOT

# Delete all core files.
rm -r includes
rm -r misc
rm -r modules
rm -r profiles
rm -r scripts
rm -r themes
rm authorize.php
rm cron.php
rm .htaccess
rm index.php
rm robots.txt
rm update.php

rsync -a /tmp/drush-dl/drupal/ $DRUPAL_ROOT/
# rm -r /tmp/drush-dl/drupal

