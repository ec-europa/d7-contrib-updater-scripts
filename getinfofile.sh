DRUPAL_ROOT_ARG=$1
MODULE_NAME=$2
MODULE_PATH=sites/all/modules/contrib/$MODULE_NAME

# Abort if DRUPAL_ROOT_ARG is empty.
if [ -z $DRUPAL_ROOT_ARG ]; then
  echo "No module name specified. Aborting dl.sh."
  exit 1;
fi

DRUPAL_ROOT=$(readlink --canonicalize $DRUPAL_ROOT_ARG)
MODULE_DIR=$DRUPAL_ROOT/$MODULE_PATH
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

# Abort if MODULE_NAME is empty.
if [ -z $MODULE_NAME ]; then
  echo "No module name specified. Aborting."
  exit 1;
fi

if [ -f $MODULE_DIR/$MODULE_NAME.info ]; then
  echo $MODULE_NAME.info
  exit 0
fi


