#!/bin/bash

DATASET_NAME=$1
DATASET_SRC=$2

echo "Dataset: ${DATASET_NAME}, Download Source: ${DATASET_SRC}"

function retry {
  local retries=$1
  shift

  local count=0
  until "$@"; do # actual command execution happening here, and will continue till signal 0 (success).
    exit=$?
    wait=$((2 ** $count))
    count=$(($count + 1))
    if [ $count -lt $retries ]; then
      echo "Retry $count/$retries exited $exit, retrying in $wait seconds..."
      sleep $wait
    else
      echo "Retry $count/$retries exited $exit, no more retries left."
      return $exit
    fi
  done
  return 0
}

# The last command executed in this function is `unzip`, which will return a non-zero exit code upon failure
function download_and_unzip_dataset_files {
  # Prepare the download URLs.
  if [ "$DATASET_NAME" == "skydio-8" ]; then
    # Description: TODO
    export GDRIVE_FILEID='1mmM1p_NpL7-pnf3iHWeWVKpsm1pcBoD5'
    ZIP_FNAME=skydio-8.zip

  elif [ "$DATASET_NAME" == "skydio-32" ]; then
    # Description: TODO
    export GDRIVE_FILEID='1BQ6jp0DD3D9yhTnrDoEddzlMYT0RRH68'
    ZIP_FNAME=skydio-32.zip

  elif [ "$DATASET_NAME" == "skydio-501" ]; then
    # 501-image Crane Mast collection released by Skydio via Sketchfab
    WGET_URL1=https://github.com/johnwlambert/gtsfm-datasets-mirror/releases/download/skydio-crane-mast-501-images/skydio-crane-mast-501-images1.tar.gz
    WGET_URL2=https://github.com/johnwlambert/gtsfm-datasets-mirror/releases/download/skydio-crane-mast-501-images/skydio-crane-mast-501-images2.tar.gz
    WGET_URL3=https://github.com/johnwlambert/gtsfm-datasets-mirror/releases/download/skydio-501-colmap-pseudo-gt/skydio-501-colmap-pseudo-gt.tar.gz

  elif [ "$DATASET_NAME" == "notre-dame-20" ]; then
    # Description: TODO
    export GDRIVE_FILEID='1t_CptH7ZWdKQVW-yw56bpLS83TntNQiK'
    ZIP_FNAME=notre-dame-20.zip

  elif [ "$DATASET_NAME" == "palace-fine-arts-281" ]; then
    # Description: TODO
    WGET_URL1=http://vision.maths.lth.se/calledataset/fine_arts_palace/fine_arts_palace.zip
    WGET_URL2=http://vision.maths.lth.se/calledataset/fine_arts_palace/data.mat
    ZIP_FNAME=fine_arts_palace.zip

  elif [ "$DATASET_NAME" == "2011205_rc3" ]; then
    # Description: images captured during the Rotation Characterization 3 (RC3) phase of NASA's Dawn mission to Asteroid 4
    #   Vesta.
    WGET_URL1=https://www.dropbox.com/s/q02mgq1unbw068t/2011205_rc3.zip
    ZIP_FNAME=2011205_rc3.zip
  fi

  # Download the data.
  if [ "$DATASET_SRC" == "gdrive" ]; then
    echo "Downloading ${DATASET_NAME} from GDRIVE"

    # delete if exists (would be truncated version from earlier retry)
    rm -f $ZIP_FNAME

    export GDRIVE_URL='https://docs.google.com/uc?export=download&id='$GDRIVE_FILEID
    retry 10 wget --save-cookies cookies.txt $GDRIVE_URL -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1/p' >confirm.txt
    retry 10 wget --load-cookies cookies.txt -O ${DATASET_NAME}.zip $GDRIVE_URL'&confirm='$(<confirm.txt)

  elif [ "$DATASET_SRC" == "wget" ]; then
    echo "Downloading ${DATASET_NAME} with WGET"
    retry 10 wget $WGET_URL1

    # Check if $WGET_URL2 has been set.
    if [ ! -z "$WGET_URL2" ]; then
      retry 10 wget $WGET_URL2
    fi
    # Check if $WGET_URL3 has been set.
    if [ ! -z "$WGET_URL3" ]; then
      retry 10 wget $WGET_URL3
    fi
    echo $WGET_URL1
    echo $WGET_URL2
  fi

  # Extract the data, configure arguments for runner.
  if [ "$DATASET_NAME" == "skydio-8" ]; then
    COLMAP_FILES_DIRPATH=skydio_crane_mast_8imgs_with_exif/crane_mast_8imgs_colmap_output
    unzip -qq skydio-8.zip

  elif [ "$DATASET_NAME" == "skydio-32" ]; then
    COLMAP_FILES_DIRPATH=skydio-32/colmap_crane_mast_32imgs
    unzip -qq skydio-32.zip -d skydio-32

  elif [ "$DATASET_NAME" == "skydio-501" ]; then
    tar -xvzf skydio-crane-mast-501-images1.tar.gz
    tar -xvzf skydio-crane-mast-501-images2.tar.gz
    tar -xvzf skydio-501-colmap-pseudo-gt.tar.gz
    IMAGES_DIR="skydio-crane-mast-501-images"
    mkdir $IMAGES_DIR
    mv skydio-crane-mast-501-images1/* $IMAGES_DIR
    mv skydio-crane-mast-501-images2/* $IMAGES_DIR
    COLMAP_FILES_DIRPATH="skydio-501-colmap-pseudo-gt"

    mkdir -p cache/detector_descriptor
    mkdir -p cache/matcher
    wget https://github.com/johnwlambert/gtsfm-cache/releases/download/skydio-501-lookahead50-deep-front-end-cache/skydio-501-lookahead50-deep-front-end-cache.tar.gz
    mkdir skydio-501-cache
    tar -xvzf skydio-501-lookahead50-deep-front-end-cache.tar.gz --directory skydio-501-cache
    cp skydio-501-cache/cache/detector_descriptor/* cache/detector_descriptor/
    cp skydio-501-cache/cache/matcher/* cache/matcher/

  elif [ "$DATASET_NAME" == "notre-dame-20" ]; then
    COLMAP_FILES_DIRPATH=notre-dame-20/notre-dame-20-colmap
    unzip -qq notre-dame-20.zip

  elif [ "$DATASET_NAME" == "palace-fine-arts-281" ]; then
    mkdir -p palace-fine-arts-281
    unzip -qq fine_arts_palace.zip -d palace-fine-arts-281/images

  elif [ "$DATASET_NAME" == "2011205_rc3" ]; then
    unzip -qq 2011205_rc3.zip
  fi
}

# Retry in case of corrupted file ("End-of-central-directory signature not found")
retry 5 download_and_unzip_dataset_files

# Set up directories
if [ "$DATASET_NAME" == "palace-fine-arts-281" ]; then
  mv data.mat palace-fine-arts-281/
fi
